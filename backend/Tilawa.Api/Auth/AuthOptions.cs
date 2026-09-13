namespace Tilawa.Api.Auth;

/// <summary>
/// Settings for the tokens this API issues.
/// </summary>
public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    /// <summary>
    /// Signing key. Must be at least 32 bytes and must be supplied through
    /// configuration or an environment variable in any non-development
    /// deployment — startup fails otherwise rather than signing with a default.
    /// </summary>
    public string SigningKey { get; set; } = string.Empty;

    public string Issuer { get; set; } = "tilawa-api";

    public string Audience { get; set; } = "tilawa-app";

    /// <summary>Short-lived, because the client can always refresh.</summary>
    public int AccessTokenMinutes { get; set; } = 60;

    public int RefreshTokenDays { get; set; } = 60;
}

/// <summary>
/// Audiences accepted from Google. These are the OAuth client ids the mobile
/// apps present; a token minted for any other audience is rejected.
/// </summary>
public sealed class GoogleAuthOptions
{
    public const string SectionName = "Auth:Google";

    public List<string> ClientIds { get; set; } = [];
}

/// <summary>
/// Audiences accepted from Apple: the iOS bundle id, plus the service id used
/// by the Android and web flows.
/// </summary>
public sealed class AppleAuthOptions
{
    public const string SectionName = "Auth:Apple";

    public List<string> ClientIds { get; set; } = [];

    public string Issuer { get; set; } = "https://appleid.apple.com";

    /// <summary>
    /// Apple's OpenID discovery document. The signing keys are read from it
    /// and refreshed automatically as Apple rotates them.
    /// </summary>
    public string MetadataAddress { get; set; } =
        "https://appleid.apple.com/.well-known/openid-configuration";
}
