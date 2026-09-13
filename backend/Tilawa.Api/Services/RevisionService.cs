using Tilawa.Api.Auth;
using Tilawa.Api.DTOs;
using Tilawa.Api.Models;
using Tilawa.Api.Repositories;

namespace Tilawa.Api.Services;

public interface IRevisionService
{
    Task<IReadOnlyCollection<SurahRevisionDto>> GetSurahsAsync(
        CancellationToken cancellationToken = default);

    Task<SurahRevisionDto?> GetPrioritySurahAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyCollection<RevisionPlanDto>> GetPlansAsync(
        CancellationToken cancellationToken = default);

    Task<RevisionPlanDto?> CreatePlanAsync(
        CreateRevisionPlanRequestDto request,
        CancellationToken cancellationToken = default);

    Task<RevisionPlanDto?> UpdatePlanAsync(
        Guid id,
        UpdateRevisionPlanRequestDto request,
        CancellationToken cancellationToken = default);

    Task<bool> DeletePlanAsync(Guid id, CancellationToken cancellationToken = default);

    Task<ProgressSummaryDto> GetProgressAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyCollection<SurahRevisionDto>> RecordSelfAssessmentAsync(
        SelfAssessmentRequestDto request,
        CancellationToken cancellationToken = default);

    Task<RecitationSessionDto> RecordRecitationSessionAsync(
        CreateRecitationSessionRequestDto request,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyCollection<RecitationSessionDto>> GetRecitationSessionsAsync(
        int limit,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Mastery, XP and streak rules for one signed-in user.
/// </summary>
public sealed class RevisionService : IRevisionService
{
    private const int MaxPlanNameLength = 80;

    private readonly IRevisionRepository _repository;
    private readonly IUserContext _user;
    private Task<ReciterProfile?>? _profile;

    private Task<ReciterProfile?> ProfileAsync(CancellationToken token) =>
        _profile ??= _repository.GetReciterProfileAsync(token);

    public RevisionService(IRevisionRepository repository, IUserContext user)
    {
        _repository = repository;
        _user = user;
    }

    public async Task<IReadOnlyCollection<SurahRevisionDto>> GetSurahsAsync(
        CancellationToken cancellationToken = default)
    {
        var rows = await _repository.GetSurahsAsync(cancellationToken);
        var habits = ReciterPreferences.PersonalRecitationHabits(await ProfileAsync(cancellationToken));
        return rows.Select(row => ToDto(row.Surah, row.Progress, habits)).ToList();
    }

    public async Task<SurahRevisionDto?> GetPrioritySurahAsync(
        CancellationToken cancellationToken = default)
    {
        var rows = await _repository.GetSurahsAsync(cancellationToken);
        var habits = ReciterPreferences.PersonalRecitationHabits(await ProfileAsync(cancellationToken));

        // Weakest first among surahs the user has actually started, so the
        // suggestion is always something they have memorised. Ranking uses the
        // decayed value, so a surah left alone for weeks rises up the list.
        var priority = rows
            .Where(row => row.Progress?.LastReviewed is not null)
            .OrderBy(row => CurrentMastery(row.Progress!, habits))
            .ThenBy(row => row.Progress!.LastReviewed)
            .Select(row => (row.Surah, row.Progress))
            .FirstOrDefault();

        return priority.Surah is null ? null : ToDto(priority.Surah, priority.Progress, habits);
    }

    public async Task<IReadOnlyCollection<RevisionPlanDto>> GetPlansAsync(
        CancellationToken cancellationToken = default)
    {
        var plans = await _repository.GetPlansAsync(cancellationToken);
        return plans.Select(ToDto).ToList();
    }

    public async Task<RevisionPlanDto?> CreatePlanAsync(
        CreateRevisionPlanRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var profile = await ProfileAsync(cancellationToken);
        if (!IsValidPlan(request.Name, request.SurahNumbers, ReciterPreferences.MaxPlanSurahs(profile?.Extent))) return null;

        var plan = new RevisionPlan
        {
            UserId = _user.UserId,
            Name = request.Name.Trim(),
            SurahNumbers = [.. request.SurahNumbers],
            ReminderTime = request.ReminderTime,
            IsActive = request.IsActive,
        };

        await _repository.AddPlanAsync(plan, cancellationToken);
        return ToDto(plan);
    }

    public async Task<RevisionPlanDto?> UpdatePlanAsync(
        Guid id,
        UpdateRevisionPlanRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var profile = await ProfileAsync(cancellationToken);
        if (!IsValidPlan(request.Name, request.SurahNumbers, ReciterPreferences.MaxPlanSurahs(profile?.Extent))) return null;

        var plan = await _repository.GetPlanAsync(id, cancellationToken);
        if (plan is null) return null;

        plan.Name = request.Name.Trim();
        plan.SurahNumbers = [.. request.SurahNumbers];
        plan.ReminderTime = request.ReminderTime;
        plan.IsActive = request.IsActive;
        plan.UpdatedAt = DateTimeOffset.UtcNow;

        await _repository.UpdatePlanAsync(plan, cancellationToken);
        return ToDto(plan);
    }

    public Task<bool> DeletePlanAsync(Guid id, CancellationToken cancellationToken = default) =>
        _repository.DeletePlanAsync(id, cancellationToken);

    public async Task<ProgressSummaryDto> GetProgressAsync(
        CancellationToken cancellationToken = default)
    {
        var rows = await _repository.GetSurahsAsync(cancellationToken);
        var plans = await _repository.GetPlansAsync(cancellationToken);
        var activity = await _repository.GetActivityDaysAsync(365, cancellationToken);
        var habits = ReciterPreferences.PersonalRecitationHabits(await ProfileAsync(cancellationToken));

        var progress = rows
            .Select(row => row.Progress)
            .Where(p => p is not null)
            .Select(p => p!)
            .ToList();

        var totalXp = progress.Sum(p =>
            (int)Math.Round(CurrentMastery(p, habits) * 120) + p.RevisionCount * 8);
        var score = activity.Sum(a => a.Score);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var reviewedToday = activity.FirstOrDefault(a => a.Date == today)?.RevisionCount ?? 0;

        // Buckets are over the whole catalogue: a surah with no progress row
        // is genuinely weak, not absent.
        var total = rows.Count;
        double MasteryOf((Surah Surah, UserSurahProgress? Progress) row) =>
            row.Progress is null ? 0 : CurrentMastery(row.Progress, habits);

        var buckets = new[]
        {
            Bucket("Excellent", rows.Count(r => MasteryOf(r) >= .8), total),
            Bucket("Good", rows.Count(r => MasteryOf(r) is >= .6 and < .8), total),
            Bucket("Shaky", rows.Count(r => MasteryOf(r) is >= .4 and < .6), total),
            Bucket("Weak", rows.Count(r => MasteryOf(r) < .4), total),
        };

        return new ProgressSummaryDto(
            totalXp,
            CalculateStreak(activity),
            score,
            plans.SelectMany(p => p.SurahNumbers).Distinct().Count(),
            reviewedToday,
            activity.Select(ToDto).ToList(),
            buckets);
    }

    public async Task<IReadOnlyCollection<SurahRevisionDto>> RecordSelfAssessmentAsync(
        SelfAssessmentRequestDto request,
        CancellationToken cancellationToken = default)
    {
        if (request.Confidence is < 1 or > 10)
        {
            throw new InvalidOperationException("Confidence must be between 1 and 10.");
        }
        if (await _repository.GetSurahAsync(request.SurahNumber, cancellationToken) is null)
        {
            throw new InvalidOperationException("Unknown surah number.");
        }
        if (request.DurationSeconds < 0 || request.QuranReadCount < 0)
        {
            throw new InvalidOperationException("Duration and read counts cannot be negative.");
        }

        var progress = await _repository.GetOrCreateProgressAsync(
            request.SurahNumber,
            cancellationToken);

        var correct = request.Confidence >= MasteryModel.SuccessConfidence;
        var habits = ReciterPreferences.PersonalRecitationHabits(await ProfileAsync(cancellationToken));

        // Rebuild from what is actually retained today, not from the value
        // recorded weeks ago, so a lapse genuinely costs something.
        progress.Mastery = MasteryModel.AfterReview(
            CurrentMastery(progress, habits),
            request.Confidence,
            progress.RevisionCount);
        progress.MistakeRate = MasteryModel.MistakeRateAfterReview(
            progress.MistakeRate,
            request.Confidence);
        progress.ConsecutiveGoodReviews = MasteryModel.ConsecutiveGoodAfterReview(
            progress.ConsecutiveGoodReviews,
            request.Confidence);
        progress.RevisionCount++;
        progress.LastReviewed = DateTimeOffset.UtcNow;
        progress.RevisionIntensity = request.Confidence > 8 ? "Light" : "Intense";
        progress.LastRevisionDurationSeconds = request.DurationSeconds;
        progress.LastRevisionSection = request.Section;
        progress.QuranReadCount += request.QuranReadCount;

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var activity = await _repository.GetOrCreateActivityDayAsync(today, cancellationToken);
        activity.RevisionCount++;
        activity.Xp += request.Confidence * 2 + (correct ? 5 : 0);
        activity.Score += request.Confidence;
        activity.SurahNumbers = [.. activity.SurahNumbers, request.SurahNumber];
        activity.DurationSeconds += request.DurationSeconds;
        activity.QuranReadCount += request.QuranReadCount;

        await _repository.SaveChangesAsync(cancellationToken);
        return await GetSurahsAsync(cancellationToken);
    }

    public async Task<RecitationSessionDto> RecordRecitationSessionAsync(
        CreateRecitationSessionRequestDto request,
        CancellationToken cancellationToken = default)
    {
        if (await _repository.GetSurahAsync(request.SurahNumber, cancellationToken) is null)
        {
            throw new InvalidOperationException("Unknown surah number.");
        }
        if (request.DurationSeconds < 0 || request.VersesMatched < 0)
        {
            throw new InvalidOperationException("Duration and verse counts cannot be negative.");
        }

        var session = new RecitationSession
        {
            UserId = _user.UserId,
            SurahNumber = request.SurahNumber,
            StartedAt = request.StartedAt,
            DurationSeconds = request.DurationSeconds,
            VersesMatched = request.VersesMatched,
            VersesAttempted = request.VersesAttempted,
            AverageConfidence = Math.Clamp(request.AverageConfidence, 0, 1),
            CoveredRefs = request.CoveredRefs.Take(2000).ToList(),
        };

        await _repository.AddRecitationSessionAsync(session, cancellationToken);
        return ToDto(session);
    }

    public async Task<IReadOnlyCollection<RecitationSessionDto>> GetRecitationSessionsAsync(
        int limit,
        CancellationToken cancellationToken = default)
    {
        var sessions = await _repository.GetRecitationSessionsAsync(
            Math.Clamp(limit, 1, 365),
            cancellationToken);
        return sessions.Select(ToDto).ToList();
    }

    /// <summary>
    /// A plan must be named, of a workable size, and reference real surahs.
    /// </summary>
    private static bool IsValidPlan(string name, IReadOnlyCollection<int> surahNumbers, int maximum) =>
        !string.IsNullOrWhiteSpace(name)
        && name.Length <= MaxPlanNameLength
        && surahNumbers.Count > 0 && surahNumbers.Count <= maximum
        && surahNumbers.All(number => number is >= 1 and <= 114);

    /// <summary>
    /// Consecutive days with at least one revision, counting back from today.
    /// </summary>
    private static int CalculateStreak(IReadOnlyCollection<ActivityDay> activity)
    {
        var dates = activity.Where(a => a.RevisionCount > 0).Select(a => a.Date).ToHashSet();
        var streak = 0;
        var cursor = DateOnly.FromDateTime(DateTime.UtcNow);
        while (dates.Contains(cursor))
        {
            streak++;
            cursor = cursor.AddDays(-1);
        }
        return streak;
    }

    private static MasteryBucketDto Bucket(string label, int count, int total) =>
        new(label, count, total == 0 ? 0 : Math.Round((double)count / total, 4));

    /// <summary>
    /// Mastery faded by the time since the last review, at the rate this
    /// particular surah fades. See <see cref="SurahDifficulty"/>.
    /// </summary>
    private static double CurrentMastery(UserSurahProgress progress, IReadOnlySet<int>? habits) =>
        MasteryModel.Current(
            progress.Mastery,
            progress.LastReviewed,
            progress.ConsecutiveGoodReviews,
            SurahDifficulty.CoefficientFor(progress.SurahNumber, habits));

    private static SurahRevisionDto ToDto(Surah surah, UserSurahProgress? progress, IReadOnlySet<int>? habits) => new(
        surah.Number,
        surah.EnglishName,
        surah.ArabicName,
        surah.JuzLabel,
        surah.AyahCount,
        Math.Round(progress?.Mastery ?? 0, 4),
        Math.Round(progress is null ? 0 : CurrentMastery(progress, habits), 4),
        Math.Round(progress?.MistakeRate ?? 0, 4),
        progress?.RevisionCount ?? 0,
        progress?.ConsecutiveGoodReviews ?? 0,
        progress?.LastReviewed,
        progress?.RevisionIntensity ?? "Light",
        progress?.LastRevisionDurationSeconds ?? 0,
        progress?.LastRevisionSection,
        progress?.QuranReadCount ?? 0);

    private static RevisionPlanDto ToDto(RevisionPlan plan) => new(
        plan.Id,
        plan.Name,
        plan.SurahNumbers.Order().ToList(),
        plan.ReminderTime,
        plan.IsActive,
        plan.CreatedAt,
        plan.UpdatedAt);

    private static ActivityDayDto ToDto(ActivityDay day) => new(
        day.Date,
        day.RevisionCount,
        day.Xp,
        day.Score,
        day.SurahNumbers.Order().ToList(),
        day.DurationSeconds,
        day.QuranReadCount);

    private static RecitationSessionDto ToDto(RecitationSession session) => new(
        session.Id,
        session.SurahNumber,
        session.StartedAt,
        session.DurationSeconds,
        session.VersesMatched,
        session.VersesAttempted,
        Math.Round(session.AverageConfidence, 4),
        session.CoveredRefs);
}
