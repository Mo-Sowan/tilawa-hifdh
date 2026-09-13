using System.IdentityModel.Tokens.Jwt;
using Google.Apis.Auth;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using Tilawa.Api.Models;

namespace Tilawa.Api.Auth;

/// <summary>
/// The identity an external provider vouched for.
/// </summary>
public sealed record VerifiedIdentity(
    AuthProvider Provider,
    string Subject,
    string Email,
    string DisplayName);

/// <summary>
/// Raised when a provider token cannot be trusted. The message is safe to log
/// but is never echoed to the client verbatim.
/// </summary>
public sealed class IdentityTokenException : Exception
{
    public IdentityTokenException(string message) : base(message) { }
}

/// <summary>
/// Verifies an identity token issued by an external provider.
/// </summary>
public interface IIdentityTokenVerifier
{
    AuthProvider Provider { get; }

    Task<VerifiedIdentity> VerifyAsync(
        string identityToken,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Verifies Google ID tokens against Google's published keys.
/// </summary>
public sealed class GoogleIdentityTokenVerifier : IIdentityTokenVerifier
{
    private readonly GoogleAuthOptions _options;

    public GoogleIdentityTokenVerifier(IOptions<GoogleAuthOptions> options)
    {
        _options = options.Value;
    }

    public AuthProvider Provider => AuthProvider.Google;

    public async Task<VerifiedIdentity> VerifyAsync(
        string identityToken,
        CancellationToken cancellationToken = default)
    {
        if (_options.ClientIds.Count == 0)
        {
            throw new IdentityTokenException("No Google client ids are configured.");
        }

        GoogleJsonWebSignature.Payload payload;
        try
        {
            // Checks the signature, issuer, audience and expiry against
            // Google's rotating key set.
            payload = await GoogleJsonWebSignature.ValidateAsync(
                identityToken,
                new GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = _options.ClientIds,
                });
        }
        catch (InvalidJwtException exception)
        {
            throw new IdentityTokenException($"Google token rejected: {exception.Message}");
        }

        if (string.IsNullOrWhiteSpace(payload.Subject))
        {
            throw new IdentityTokenException("Google token carried no subject claim.");
        }

        return new VerifiedIdentity(
            AuthProvider.Google,
            payload.Subject,
            payload.Email ?? string.Empty,
            payload.Name ?? string.Empty);
    }
}

/// <summary>
/// Verifies Sign in with Apple identity tokens against Apple's JWKS endpoint.
/// </summary>
/// <remarks>
/// The key set is fetched through <see cref="ConfigurationManager{T}"/>, which
/// caches it and refreshes on rotation, so a token check does not hit Apple on
/// every request.
/// </remarks>
public sealed class AppleIdentityTokenVerifier : IIdentityTokenVerifier
{
    private readonly AppleAuthOptions _options;
    private readonly IConfigurationManager<OpenIdConnectConfiguration> _configuration;
    private readonly JwtSecurityTokenHandler _handler = new();

    public AppleIdentityTokenVerifier(
        IOptions<AppleAuthOptions> options,
        IConfigurationManager<OpenIdConnectConfiguration> configurationManager)
    {
        _options = options.Value;
        _configuration = configurationManager;
    }

    public AuthProvider Provider => AuthProvider.Apple;

    public async Task<VerifiedIdentity> VerifyAsync(
        string identityToken,
        CancellationToken cancellationToken = default)
    {
        if (_options.ClientIds.Count == 0)
        {
            throw new IdentityTokenException("No Apple client ids are configured.");
        }

        var configuration = await _configuration.GetConfigurationAsync(cancellationToken);

        var parameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = _options.Issuer,
            ValidateAudience = true,
            ValidAudiences = _options.ClientIds,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            IssuerSigningKeys = configuration.SigningKeys,
            ClockSkew = TimeSpan.FromMinutes(2),
        };

        try
        {
            var principal = _handler.ValidateToken(identityToken, parameters, out _);

            var subject = principal.FindFirst("sub")?.Value;
            if (string.IsNullOrWhiteSpace(subject))
            {
                throw new IdentityTokenException("Apple token carried no subject claim.");
            }

            // Apple omits the name entirely and may substitute a private relay
            // address, so both are best-effort.
            var email = principal.FindFirst("email")?.Value ?? string.Empty;
            return new VerifiedIdentity(AuthProvider.Apple, subject, email, string.Empty);
        }
        catch (SecurityTokenException exception)
        {
            throw new IdentityTokenException($"Apple token rejected: {exception.Message}");
        }
    }
}
