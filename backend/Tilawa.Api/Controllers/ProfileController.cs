using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tilawa.Api.Data;
using Tilawa.Api.DTOs;
using Tilawa.Api.Models;
using Tilawa.Api.Auth;

namespace Tilawa.Api.Controllers;

/// <summary>
/// The reciter's onboarding answers.
/// </summary>
/// <remarks>
/// The device is the source of truth: the app works signed out, so the answers
/// are given and used long before this endpoint ever sees them. A PUT replaces
/// whatever is stored rather than merging, because the app always sends the
/// complete set it holds.
/// </remarks>
[ApiController]
[Route("api/v1/profile")]
[Authorize]
public sealed class ProfileController : ControllerBase
{
    private const char ChoiceSeparator = ',';

    private readonly TilawaDbContext _database;
    private readonly IUserContext _user;

    public ProfileController(TilawaDbContext database, IUserContext user)
    {
        _database = database;
        _user = user;
    }

    /// <summary>The stored answers, or 404 if this account has none yet.</summary>
    [HttpGet]
    public async Task<ActionResult<ReciterProfileDto>> Get(
        CancellationToken cancellationToken)
    {
        var profile = await _database.ReciterProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == _user.UserId, cancellationToken);

        return profile is null ? NotFound() : Ok(ToDto(profile));
    }

    /// <summary>Replaces this account's answers with the ones supplied.</summary>
    [HttpPut]
    public async Task<ActionResult<ReciterProfileDto>> Put(
        ReciterProfileDto request,
        CancellationToken cancellationToken)
    {
        var profile = await _database.ReciterProfiles
            .FirstOrDefaultAsync(p => p.UserId == _user.UserId, cancellationToken);

        if (profile is null)
        {
            profile = new ReciterProfile { UserId = _user.UserId };
            _database.ReciterProfiles.Add(profile);
        }

        profile.Extent = request.Extent;
        profile.Difficulty = request.Difficulty;
        profile.FrequentlyRecited = string.Join(
            ChoiceSeparator,
            request.FrequentlyRecited ?? Array.Empty<string>());
        profile.Goal = request.Goal;
        profile.CompletedAt = request.CompletedAt;
        profile.UpdatedAt = DateTimeOffset.UtcNow;

        await _database.SaveChangesAsync(cancellationToken);
        return Ok(ToDto(profile));
    }

    private static ReciterProfileDto ToDto(ReciterProfile profile) => new(
        profile.Extent,
        profile.Difficulty,
        profile.FrequentlyRecited
            .Split(ChoiceSeparator, StringSplitOptions.RemoveEmptyEntries)
            .ToArray(),
        profile.Goal,
        profile.CompletedAt);
}
