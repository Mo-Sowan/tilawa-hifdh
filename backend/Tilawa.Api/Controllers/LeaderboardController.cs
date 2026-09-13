using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tilawa.Api.Auth;
using Tilawa.Api.Data;
using Tilawa.Api.DTOs;
using Tilawa.Api.Models;
using Tilawa.Api.Services;

namespace Tilawa.Api.Controllers;

/// <summary>
/// Standings, and who the signed-in reciter follows.
/// </summary>
[ApiController]
[Route("api/v1/leaderboard")]
[Authorize]
public sealed class LeaderboardController : ControllerBase
{
    private const int MaxLimit = 100;

    private readonly ILeaderboardService _service;
    private readonly TilawaDbContext _database;
    private readonly IUserContext _user;

    public LeaderboardController(
        ILeaderboardService service,
        TilawaDbContext database,
        IUserContext user)
    {
        _service = service;
        _database = database;
        _user = user;
    }

    /// <summary>The board, global or limited to who this reciter follows.</summary>
    [HttpGet]
    public async Task<ActionResult<LeaderboardDto>> Get(
        [FromQuery] string scope,
        [FromQuery] int limit,
        CancellationToken cancellationToken)
    {
        var parsed = string.Equals(scope, "friends", StringComparison.OrdinalIgnoreCase)
            ? LeaderboardScope.Friends
            : LeaderboardScope.Global;

        return Ok(await _service.GetAsync(
            parsed,
            Math.Clamp(limit <= 0 ? 10 : limit, 1, MaxLimit),
            cancellationToken));
    }

    /// <summary>Follows another reciter, found by the address they signed up with.</summary>
    [HttpPost("friends")]
    public async Task<ActionResult> AddFriend(
        AddFriendRequest request,
        CancellationToken cancellationToken)
    {
        var email = request.Email?.Trim();
        if (string.IsNullOrWhiteSpace(email))
        {
            return BadRequest(new { error = "An email address is required." });
        }

        var friend = await _database.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(
                user => user.Email == email,
                cancellationToken);

        // Deliberately the same answer whether the address is unknown or is
        // the caller's own, so this cannot be used to test who has an account.
        if (friend is null || friend.Id == _user.UserId)
        {
            return NotFound(new { error = "No reciter with that address." });
        }

        var already = await _database.Friendships.AnyAsync(
            link => link.UserId == _user.UserId && link.FriendUserId == friend.Id,
            cancellationToken);

        if (!already)
        {
            _database.Friendships.Add(new Friendship
            {
                UserId = _user.UserId,
                FriendUserId = friend.Id,
            });
            await _database.SaveChangesAsync(cancellationToken);
        }

        return NoContent();
    }

    /// <summary>Stops following a reciter.</summary>
    [HttpDelete("friends/{friendUserId:guid}")]
    public async Task<ActionResult> RemoveFriend(
        Guid friendUserId,
        CancellationToken cancellationToken)
    {
        var link = await _database.Friendships.FirstOrDefaultAsync(
            item => item.UserId == _user.UserId && item.FriendUserId == friendUserId,
            cancellationToken);

        if (link is not null)
        {
            _database.Friendships.Remove(link);
            await _database.SaveChangesAsync(cancellationToken);
        }

        return NoContent();
    }
}
