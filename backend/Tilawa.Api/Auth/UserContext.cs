using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace Tilawa.Api.Auth;

/// <summary>
/// The account the current request belongs to.
/// </summary>
/// <remarks>
/// Every repository call is scoped through this, so a request can only ever
/// reach its own rows.
/// </remarks>
public interface IUserContext
{
    /// <summary>The signed-in user's id.</summary>
    /// <exception cref="InvalidOperationException">
    /// Thrown when the request is not authenticated. Controllers carry
    /// <c>[Authorize]</c>, so reaching this state means a misconfiguration
    /// rather than an anonymous caller.
    /// </exception>
    Guid UserId { get; }

    bool IsAuthenticated { get; }
}

public sealed class HttpUserContext : IUserContext
{
    private readonly IHttpContextAccessor _accessor;

    public HttpUserContext(IHttpContextAccessor accessor)
    {
        _accessor = accessor;
    }

    public bool IsAuthenticated => TryGetUserId(out _);

    public Guid UserId => TryGetUserId(out var id)
        ? id
        : throw new InvalidOperationException("The request is not authenticated.");

    private bool TryGetUserId(out Guid userId)
    {
        userId = Guid.Empty;
        var principal = _accessor.HttpContext?.User;
        if (principal is null) return false;

        // JwtBearer maps `sub` onto ClaimTypes.NameIdentifier unless inbound
        // claim mapping is disabled, so accept either spelling.
        var raw = principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);

        return Guid.TryParse(raw, out userId);
    }
}
