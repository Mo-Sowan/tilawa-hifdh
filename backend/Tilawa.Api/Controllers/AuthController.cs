using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tilawa.Api.Auth;
using Tilawa.Api.DTOs;
using Tilawa.Api.Models;

namespace Tilawa.Api.Controllers;

/// <summary>
/// Federated sign-in. The API never sees a password: it verifies an identity
/// token minted by Google or Apple and issues its own session in exchange.
/// </summary>
[ApiController]
[Route("api/v1/auth")]
[AllowAnonymous]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _auth;
    private readonly ILogger<AuthController> _logger;

    public AuthController(IAuthService auth, ILogger<AuthController> logger)
    {
        _auth = auth;
        _logger = logger;
    }

    /// <summary>Exchanges a Google ID token for a Tilawa session.</summary>
    [HttpPost("google")]
    public Task<ActionResult<AuthSessionDto>> Google(
        [FromBody] SignInRequestDto request,
        CancellationToken cancellationToken) =>
        SignInAsync(AuthProvider.Google, request, cancellationToken);

    /// <summary>Exchanges an Apple identity token for a Tilawa session.</summary>
    [HttpPost("apple")]
    public Task<ActionResult<AuthSessionDto>> Apple(
        [FromBody] SignInRequestDto request,
        CancellationToken cancellationToken) =>
        SignInAsync(AuthProvider.Apple, request, cancellationToken);

    /// <summary>Rotates a refresh token for a fresh session.</summary>
    [HttpPost("refresh")]
    public async Task<ActionResult<AuthSessionDto>> Refresh(
        [FromBody] RefreshRequestDto request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            return BadRequest("A refresh token is required.");
        }

        var session = await _auth.RefreshAsync(request.RefreshToken, cancellationToken);
        // Expired, revoked or unknown are all the same to the caller: sign in
        // again. Distinguishing them would leak which tokens exist.
        return session is null ? Unauthorized() : Ok(session);
    }

    /// <summary>Revokes a refresh token. Always reports success.</summary>
    [HttpPost("sign-out")]
    public async Task<IActionResult> SignOutSession(
        [FromBody] RefreshRequestDto request,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            await _auth.SignOutAsync(request.RefreshToken, cancellationToken);
        }
        return NoContent();
    }

    private async Task<ActionResult<AuthSessionDto>> SignInAsync(
        AuthProvider provider,
        SignInRequestDto request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.IdentityToken))
        {
            return BadRequest("An identity token is required.");
        }

        try
        {
            var session = await _auth.SignInAsync(
                provider,
                request.IdentityToken,
                request.DisplayName,
                cancellationToken);
            return Ok(session);
        }
        catch (IdentityTokenException exception)
        {
            // Log the provider's reason, return a generic rejection.
            _logger.LogWarning("{Provider} sign-in rejected: {Reason}", provider, exception.Message);
            return Unauthorized();
        }
    }
}
