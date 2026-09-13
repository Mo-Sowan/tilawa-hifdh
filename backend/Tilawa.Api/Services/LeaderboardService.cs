using Microsoft.EntityFrameworkCore;
using Tilawa.Api.Auth;
using Tilawa.Api.Data;
using Tilawa.Api.DTOs;

namespace Tilawa.Api.Services;

/// <summary>Which set of reciters a board covers.</summary>
public enum LeaderboardScope
{
    Global,
    Friends,
}

public interface ILeaderboardService
{
    Task<LeaderboardDto> GetAsync(
        LeaderboardScope scope,
        int limit,
        CancellationToken cancellationToken);
}

/// <summary>
/// Ranks reciters by the work they have actually recorded.
/// </summary>
/// <remarks>
/// <para>
/// Everything here is derived from <c>ActivityDays</c>, the same rows the
/// reciter's own calendar is drawn from, so a position on the board and the
/// numbers on their dashboard can never disagree.
/// </para>
/// <para>
/// Ordered by total XP. Streaks are the more motivating number but a poor
/// ranking: they reward showing up over doing anything, and reset to zero on a
/// single missed day, which would make the board lurch.
/// </para>
/// </remarks>
public sealed class LeaderboardService : ILeaderboardService
{
    private readonly TilawaDbContext _database;
    private readonly IUserContext _user;

    public LeaderboardService(TilawaDbContext database, IUserContext user)
    {
        _database = database;
        _user = user;
    }

    public async Task<LeaderboardDto> GetAsync(
        LeaderboardScope scope,
        int limit,
        CancellationToken cancellationToken)
    {
        var eligible = await EligibleUserIdsAsync(scope, cancellationToken);

        // Pulled in one pass and folded in memory. The per-user aggregates
        // below — a streak in particular — are sequential over dates, which
        // SQLite cannot express without a window function per row.
        var activity = await _database.ActivityDays
            .AsNoTracking()
            .Where(day => eligible.Contains(day.UserId))
            .Select(day => new
            {
                day.UserId,
                day.Date,
                day.Xp,
                day.RevisionCount,
            })
            .ToListAsync(cancellationToken);

        var names = await _database.Users
            .AsNoTracking()
            .Where(user => eligible.Contains(user.Id))
            .Select(user => new { user.Id, user.DisplayName, user.Email })
            .ToDictionaryAsync(user => user.Id, cancellationToken);

        var today = DateOnly.FromDateTime(DateTimeOffset.UtcNow.UtcDateTime);

        var rows = activity
            .GroupBy(day => day.UserId)
            .Select(group =>
            {
                var days = group.ToList();
                var name = names.GetValueOrDefault(group.Key);
                return new
                {
                    UserId = group.Key,
                    DisplayName = Describe(name?.DisplayName, name?.Email),
                    TotalXp = days.Sum(day => day.Xp),
                    Streak = StreakEndingAt(today, days.Select(d => d.Date)),
                    ReviewedToday = days
                        .Where(day => day.Date == today)
                        .Sum(day => day.RevisionCount),
                };
            })
            .OrderByDescending(row => row.TotalXp)
            .ThenByDescending(row => row.Streak)
            // A stable tiebreak, so equal scores do not swap places between
            // requests and make the board look like it is churning.
            .ThenBy(row => row.UserId)
            .ToList();

        var entries = rows
            .Select((row, index) => new LeaderboardEntryDto(
                index + 1,
                row.UserId,
                row.DisplayName,
                row.Streak,
                row.TotalXp,
                row.ReviewedToday,
                row.UserId == _user.UserId))
            .ToList();

        var mine = entries.FirstOrDefault(entry => entry.IsCurrentUser);

        return new LeaderboardDto(
            entries.Take(limit).ToList(),
            // Sent whatever their rank, so the app can pin it without having
            // to work out whether it already appears in the page above.
            mine);
    }

    private async Task<HashSet<Guid>> EligibleUserIdsAsync(
        LeaderboardScope scope,
        CancellationToken cancellationToken)
    {
        if (scope == LeaderboardScope.Global)
        {
            var all = await _database.Users
                .AsNoTracking()
                .Select(user => user.Id)
                .ToListAsync(cancellationToken);
            return all.ToHashSet();
        }

        var followed = await _database.Friendships
            .AsNoTracking()
            .Where(link => link.UserId == _user.UserId)
            .Select(link => link.FriendUserId)
            .ToListAsync(cancellationToken);
        var friends = followed.ToHashSet();

        // The reciter is always on their own friends board; a ranking they do
        // not appear in is not one they can read anything from.
        friends.Add(_user.UserId);
        return friends;
    }

    /// <summary>
    /// Consecutive days of activity ending today, or ending yesterday if today
    /// has not been used yet — a streak built yesterday should not read as
    /// broken simply because this morning's revision has not happened.
    /// </summary>
    internal static int StreakEndingAt(DateOnly today, IEnumerable<DateOnly> dates)
    {
        var active = dates.ToHashSet();
        var day = active.Contains(today) ? today : today.AddDays(-1);

        var streak = 0;
        while (active.Contains(day))
        {
            streak++;
            day = day.AddDays(-1);
        }
        return streak;
    }

    /// <summary>
    /// What to call someone who never supplied a name. Apple accounts often
    /// have neither a name nor a real address, so the local part of the email
    /// is the last thing worth trying before giving up.
    /// </summary>
    private static string Describe(string? displayName, string? email)
    {
        if (!string.IsNullOrWhiteSpace(displayName)) return displayName;
        if (!string.IsNullOrWhiteSpace(email))
        {
            var at = email.IndexOf('@');
            return at > 0 ? email[..at] : email;
        }
        return "Reciter";
    }
}
