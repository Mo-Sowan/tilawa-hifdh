using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Tilawa.Api.Data;
using Tilawa.Api.DTOs;
using Tilawa.Api.Models;

namespace Tilawa.Api.Auth;

public interface IAuthService
{
    /// <summary>
    /// Verifies a provider identity token, creates the account if it is new,
    /// and issues a Tilawa session.
    /// </summary>
    Task<AuthSessionDto> SignInAsync(
        AuthProvider provider,
        string identityToken,
        string? displayName,
        CancellationToken cancellationToken = default);

    /// <summary>Rotates a refresh token for a new session.</summary>
    Task<AuthSessionDto?> RefreshAsync(
        string refreshToken,
        CancellationToken cancellationToken = default);

    /// <summary>Revokes a refresh token. Idempotent.</summary>
    Task SignOutAsync(string refreshToken, CancellationToken cancellationToken = default);
}

public sealed class AuthService : IAuthService
{
    private readonly TilawaDbContext _db;
    private readonly IEnumerable<IIdentityTokenVerifier> _verifiers;
    private readonly JwtOptions _jwt;

    public AuthService(
        TilawaDbContext db,
        IEnumerable<IIdentityTokenVerifier> verifiers,
        IOptions<JwtOptions> jwt)
    {
        _db = db;
        _verifiers = verifiers;
        _jwt = jwt.Value;
    }

    public async Task<AuthSessionDto> SignInAsync(
        AuthProvider provider,
        string identityToken,
        string? displayName,
        CancellationToken cancellationToken = default)
    {
        var verifier = _verifiers.FirstOrDefault(v => v.Provider == provider)
            ?? throw new IdentityTokenException($"No verifier registered for {provider}.");

        var identity = await verifier.VerifyAsync(identityToken, cancellationToken);

        var user = await _db.Users.FirstOrDefaultAsync(
            u => u.Provider == provider && u.ProviderSubject == identity.Subject,
            cancellationToken);

        if (user is null)
        {
            user = new User
            {
                Provider = provider,
                ProviderSubject = identity.Subject,
                Email = identity.Email,
                DisplayName = FirstNonEmpty(displayName, identity.DisplayName, identity.Email),
            };
            _db.Users.Add(user);
        }
        else
        {
            // Apple sends the name only on the first authorization, so never
            // overwrite a stored name with an empty one.
            if (!string.IsNullOrWhiteSpace(identity.Email)) user.Email = identity.Email;
            var incomingName = FirstNonEmpty(displayName, identity.DisplayName);
            if (!string.IsNullOrWhiteSpace(incomingName)) user.DisplayName = incomingName;
            user.LastSignedInAt = DateTimeOffset.UtcNow;
        }

        await _db.SaveChangesAsync(cancellationToken);
        return await IssueSessionAsync(user, cancellationToken);
    }

    public async Task<AuthSessionDto?> RefreshAsync(
        string refreshToken,
        CancellationToken cancellationToken = default)
    {
        var hash = HashToken(refreshToken);
        var stored = await _db.RefreshTokens
            .FirstOrDefaultAsync(t => t.TokenHash == hash, cancellationToken);

        if (stored is null || !stored.IsActive) return null;

        var user = await _db.Users.FindAsync([stored.UserId], cancellationToken);
        if (user is null) return null;

        // Single use: rotate so a stolen token is worthless once the real
        // client has redeemed it.
        stored.RevokedAt = DateTimeOffset.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        return await IssueSessionAsync(user, cancellationToken);
    }

    public async Task SignOutAsync(
        string refreshToken,
        CancellationToken cancellationToken = default)
    {
        var hash = HashToken(refreshToken);
        var stored = await _db.RefreshTokens
            .FirstOrDefaultAsync(t => t.TokenHash == hash, cancellationToken);
        if (stored is null || stored.RevokedAt is not null) return;

        stored.RevokedAt = DateTimeOffset.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
    }

    private async Task<AuthSessionDto> IssueSessionAsync(
        User user,
        CancellationToken cancellationToken)
    {
        var expiresAt = DateTimeOffset.UtcNow.AddMinutes(_jwt.AccessTokenMinutes);
        var accessToken = CreateAccessToken(user, expiresAt);

        var refreshToken = CreateRefreshToken();
        _db.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = HashToken(refreshToken),
            ExpiresAt = DateTimeOffset.UtcNow.AddDays(_jwt.RefreshTokenDays),
        });

        await PruneExpiredTokensAsync(user.Id, cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);

        return new AuthSessionDto(
            accessToken,
            refreshToken,
            expiresAt,
            new AuthUserDto(
                user.Id,
                user.Email,
                user.DisplayName,
                user.Provider.ToString().ToLowerInvariant()));
    }

    private string CreateAccessToken(User user, DateTimeOffset expiresAt)
    {
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.SigningKey)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _jwt.Issuer,
            audience: _jwt.Audience,
            claims:
            [
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
                new Claim(JwtRegisteredClaimNames.Email, user.Email),
                new Claim("provider", user.Provider.ToString().ToLowerInvariant()),
            ],
            expires: expiresAt.UtcDateTime,
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    /// <summary>Removes tokens that can no longer be redeemed.</summary>
    private async Task PruneExpiredTokensAsync(Guid userId, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var revokedCutoff = now.AddDays(-1);

        // The date comparisons are done in memory: the SQLite provider cannot
        // translate DateTimeOffset predicates, and a user only ever has a
        // handful of refresh tokens (one per signed-in device).
        var tokens = await _db.RefreshTokens
            .Where(t => t.UserId == userId)
            .ToListAsync(cancellationToken);

        var stale = tokens
            .Where(t => t.ExpiresAt < now ||
                        (t.RevokedAt is not null && t.RevokedAt < revokedCutoff))
            .ToList();

        if (stale.Count > 0) _db.RefreshTokens.RemoveRange(stale);
    }

    private static string CreateRefreshToken() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));

    private static string HashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private static string FirstNonEmpty(params string?[] values) =>
        values.FirstOrDefault(v => !string.IsNullOrWhiteSpace(v)) ?? string.Empty;
}
