using Microsoft.EntityFrameworkCore;
using Tilawa.Api.Auth;
using Tilawa.Api.Data;
using Tilawa.Api.Models;

namespace Tilawa.Api.Repositories;

/// <summary>
/// Data access for the signed-in user's revision state.
/// </summary>
/// <remarks>
/// Implementations resolve the user from <see cref="IUserContext"/> rather
/// than taking an id parameter, so a caller cannot accidentally read another
/// account's rows.
/// </remarks>
public interface IRevisionRepository
{
    Task<ReciterProfile?> GetReciterProfileAsync(CancellationToken cancellationToken = default);
    /// <summary>The full catalogue joined with this user's progress.</summary>
    Task<IReadOnlyCollection<(Surah Surah, UserSurahProgress? Progress)>> GetSurahsAsync(
        CancellationToken cancellationToken = default);

    Task<Surah?> GetSurahAsync(int number, CancellationToken cancellationToken = default);

    /// <summary>
    /// The user's progress row for a surah, created on first use so a new
    /// account does not need 114 rows up front.
    /// </summary>
    Task<UserSurahProgress> GetOrCreateProgressAsync(
        int surahNumber,
        CancellationToken cancellationToken = default);

    Task SaveChangesAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyCollection<RevisionPlan>> GetPlansAsync(
        CancellationToken cancellationToken = default);

    Task<RevisionPlan?> GetPlanAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddPlanAsync(RevisionPlan plan, CancellationToken cancellationToken = default);

    Task UpdatePlanAsync(RevisionPlan plan, CancellationToken cancellationToken = default);

    Task<bool> DeletePlanAsync(Guid id, CancellationToken cancellationToken = default);

    Task<IReadOnlyCollection<ActivityDay>> GetActivityDaysAsync(
        int limit,
        CancellationToken cancellationToken = default);

    Task<ActivityDay> GetOrCreateActivityDayAsync(
        DateOnly date,
        CancellationToken cancellationToken = default);

    Task AddRecitationSessionAsync(
        RecitationSession session,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyCollection<RecitationSession>> GetRecitationSessionsAsync(
        int limit,
        CancellationToken cancellationToken = default);
}

public sealed class RevisionRepository : IRevisionRepository
{
    private readonly TilawaDbContext _db;
    private readonly IUserContext _user;

    public RevisionRepository(TilawaDbContext db, IUserContext user)
    {
        _db = db;
        _user = user;
    }

    public Task<ReciterProfile?> GetReciterProfileAsync(CancellationToken cancellationToken = default) =>
        _db.ReciterProfiles.AsNoTracking().FirstOrDefaultAsync(p => p.UserId == _user.UserId, cancellationToken);

    public async Task<IReadOnlyCollection<(Surah Surah, UserSurahProgress? Progress)>>
        GetSurahsAsync(CancellationToken cancellationToken = default)
    {
        var userId = _user.UserId;
        var surahs = await _db.Surahs
            .AsNoTracking()
            .OrderBy(s => s.Number)
            .ToListAsync(cancellationToken);

        var progress = await _db.UserSurahProgress
            .AsNoTracking()
            .Where(p => p.UserId == userId)
            .ToDictionaryAsync(p => p.SurahNumber, cancellationToken);

        return surahs
            .Select(s => (s, progress.GetValueOrDefault(s.Number)))
            .ToList();
    }

    public Task<Surah?> GetSurahAsync(int number, CancellationToken cancellationToken = default) =>
        _db.Surahs.AsNoTracking().FirstOrDefaultAsync(s => s.Number == number, cancellationToken);

    public async Task<UserSurahProgress> GetOrCreateProgressAsync(
        int surahNumber,
        CancellationToken cancellationToken = default)
    {
        var userId = _user.UserId;
        var progress = await _db.UserSurahProgress
            .FirstOrDefaultAsync(
                p => p.UserId == userId && p.SurahNumber == surahNumber,
                cancellationToken);

        if (progress is not null) return progress;

        progress = new UserSurahProgress
        {
            UserId = userId,
            SurahNumber = surahNumber,
        };
        _db.UserSurahProgress.Add(progress);
        return progress;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        _db.SaveChangesAsync(cancellationToken);

    public async Task<IReadOnlyCollection<RevisionPlan>> GetPlansAsync(
        CancellationToken cancellationToken = default)
    {
        var userId = _user.UserId;
        return await _db.RevisionPlans
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<RevisionPlan?> GetPlanAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        var userId = _user.UserId;
        return await _db.RevisionPlans
            .FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId, cancellationToken);
    }

    public async Task AddPlanAsync(
        RevisionPlan plan,
        CancellationToken cancellationToken = default)
    {
        _db.RevisionPlans.Add(plan);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task UpdatePlanAsync(
        RevisionPlan plan,
        CancellationToken cancellationToken = default)
    {
        _db.RevisionPlans.Update(plan);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task<bool> DeletePlanAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        var plan = await GetPlanAsync(id, cancellationToken);
        if (plan is null) return false;

        _db.RevisionPlans.Remove(plan);
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<IReadOnlyCollection<ActivityDay>> GetActivityDaysAsync(
        int limit,
        CancellationToken cancellationToken = default)
    {
        var userId = _user.UserId;
        return await _db.ActivityDays
            .Where(a => a.UserId == userId)
            .OrderByDescending(a => a.Date)
            .Take(limit)
            .ToListAsync(cancellationToken);
    }

    public async Task<ActivityDay> GetOrCreateActivityDayAsync(
        DateOnly date,
        CancellationToken cancellationToken = default)
    {
        var userId = _user.UserId;
        var day = await _db.ActivityDays
            .FirstOrDefaultAsync(a => a.UserId == userId && a.Date == date, cancellationToken);

        if (day is not null) return day;

        day = new ActivityDay { UserId = userId, Date = date };
        _db.ActivityDays.Add(day);
        return day;
    }

    public async Task AddRecitationSessionAsync(
        RecitationSession session,
        CancellationToken cancellationToken = default)
    {
        _db.RecitationSessions.Add(session);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<RecitationSession>> GetRecitationSessionsAsync(
        int limit,
        CancellationToken cancellationToken = default)
    {
        var userId = _user.UserId;
        return await _db.RecitationSessions
            .AsNoTracking()
            .Where(s => s.UserId == userId)
            .OrderByDescending(s => s.StartedAt)
            .Take(limit)
            .ToListAsync(cancellationToken);
    }
}
