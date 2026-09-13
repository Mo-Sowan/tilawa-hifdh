using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Tilawa.Api.Auth;
using Tilawa.Api.Data;
using Tilawa.Api.Models;

namespace Tilawa.Api.Tests;

/// <summary>
/// Stands in for Google and Apple so sign-in can be exercised without live
/// provider tokens. The subject is taken straight from the supplied token, so
/// a test can choose which account it is signing in as.
/// </summary>
public sealed class FakeIdentityTokenVerifier : IIdentityTokenVerifier
{
    public FakeIdentityTokenVerifier(AuthProvider provider)
    {
        Provider = provider;
    }

    public AuthProvider Provider { get; }

    /// <summary>Tokens containing this marker are rejected.</summary>
    public const string InvalidToken = "invalid";

    public Task<VerifiedIdentity> VerifyAsync(
        string identityToken,
        CancellationToken cancellationToken = default)
    {
        if (identityToken.Contains(InvalidToken, StringComparison.Ordinal))
        {
            throw new IdentityTokenException("Fake verifier rejected the token.");
        }

        var subject = $"{Provider.ToString().ToLowerInvariant()}-{identityToken}";
        return Task.FromResult(new VerifiedIdentity(
            Provider,
            subject,
            $"{identityToken}@example.test",
            string.Empty));
    }
}

/// <summary>
/// Boots the API in-process against a throwaway SQLite file.
/// </summary>
public sealed class TilawaApiFactory : WebApplicationFactory<Program>
{
    private readonly string _databasePath =
        Path.Combine(Path.GetTempPath(), $"tilawa-tests-{Guid.NewGuid():N}.db");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment(Environments.Development);

        builder.ConfigureServices(services =>
        {
            // Point the context at this test's own database file.
            services.RemoveAll<DbContextOptions<TilawaDbContext>>();
            services.RemoveAll<TilawaDbContext>();
            services.AddDbContext<TilawaDbContext>(options =>
                options.UseSqlite($"Data Source={_databasePath}"));

            // Never reach out to Google or Apple from a test.
            services.RemoveAll<IIdentityTokenVerifier>();
            services.AddScoped<IIdentityTokenVerifier>(
                _ => new FakeIdentityTokenVerifier(AuthProvider.Google));
            services.AddScoped<IIdentityTokenVerifier>(
                _ => new FakeIdentityTokenVerifier(AuthProvider.Apple));
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (!disposing) return;

        try
        {
            if (File.Exists(_databasePath)) File.Delete(_databasePath);
        }
        catch (IOException)
        {
            // The temp file is disposable either way; a locked handle on
            // Windows must not fail the test run.
        }
    }
}
