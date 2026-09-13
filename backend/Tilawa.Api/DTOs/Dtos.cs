namespace Tilawa.Api.DTOs;

// --- Auth -------------------------------------------------------------------

/// <summary>The signed-in account, as the client sees it.</summary>
public sealed record AuthUserDto(
    Guid Id,
    string Email,
    string DisplayName,
    string Provider);

/// <summary>An issued session: a short-lived access token plus its refresh.</summary>
public sealed record AuthSessionDto(
    string AccessToken,
    string RefreshToken,
    DateTimeOffset ExpiresAt,
    AuthUserDto User);

/// <param name="IdentityToken">Google ID token or Apple identity token.</param>
/// <param name="AuthorizationCode">Apple's one-time code. Unused by Google.</param>
/// <param name="DisplayName">
/// Only sent on a first Apple authorization, where the token itself carries no
/// name.
/// </param>
public sealed record SignInRequestDto(
    string IdentityToken,
    string? AuthorizationCode = null,
    string? DisplayName = null);

public sealed record RefreshRequestDto(string RefreshToken);

// --- Revision ---------------------------------------------------------------

/// <param name="MasteryAtReview">
/// Mastery at the end of the last review. Clients apply the same decay the API
/// does, so the wire carries a stable fact rather than a figure that is already
/// stale by the time it arrives.
/// </param>
/// <param name="Mastery">The decayed value, for clients that just want to show it.</param>
public sealed record SurahRevisionDto(
    int Number,
    string EnglishName,
    string ArabicName,
    string JuzLabel,
    int AyahCount,
    double MasteryAtReview,
    double Mastery,
    double MistakeRate,
    int RevisionCount,
    int ConsecutiveGoodReviews,
    DateTimeOffset? LastReviewed,
    string RevisionIntensity,
    int LastRevisionDurationSeconds,
    string? LastRevisionSection,
    int QuranReadCount);

/// <param name="SurahNumber">1-114.</param>
/// <param name="Confidence">The user's own recall estimate, 1-10.</param>
/// <param name="DurationSeconds">Length of the revision session.</param>
/// <param name="Section">Free text such as "Ayahs 1-10".</param>
/// <param name="QuranReadCount">Mushaf opens during the session.</param>
public sealed record SelfAssessmentRequestDto(
    int SurahNumber,
    int Confidence,
    int DurationSeconds,
    string? Section,
    int QuranReadCount);

// --- Plans ------------------------------------------------------------------

public sealed record RevisionPlanDto(
    Guid Id,
    string Name,
    IReadOnlyCollection<int> SurahNumbers,
    DateTimeOffset ReminderTime,
    bool IsActive,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record CreateRevisionPlanRequestDto(
    string Name,
    IReadOnlyCollection<int> SurahNumbers,
    DateTimeOffset ReminderTime,
    bool IsActive = true);

public sealed record UpdateRevisionPlanRequestDto(
    string Name,
    IReadOnlyCollection<int> SurahNumbers,
    DateTimeOffset ReminderTime,
    bool IsActive);

// --- Activity ---------------------------------------------------------------

public sealed record ActivityDayDto(
    DateOnly Date,
    int RevisionCount,
    int Xp,
    int Score,
    IReadOnlyCollection<int> SurahNumbers,
    int DurationSeconds,
    int QuranReadCount);

public sealed record MasteryBucketDto(string Label, int Count, double Ratio);

public sealed record ProgressSummaryDto(
    int TotalXp,
    int Streak,
    int Score,
    int PlannedSurahs,
    int ReviewedToday,
    IReadOnlyCollection<ActivityDayDto> Calendar,
    IReadOnlyCollection<MasteryBucketDto> MasteryBuckets);

// --- Recitation -------------------------------------------------------------

/// <summary>
/// The outcome of one on-device follow-along session. No audio is uploaded.
/// </summary>
public sealed record RecitationSessionDto(
    Guid Id,
    int SurahNumber,
    DateTimeOffset StartedAt,
    int DurationSeconds,
    int VersesMatched,
    int VersesAttempted,
    double AverageConfidence,
    IReadOnlyCollection<string> CoveredRefs);

public sealed record CreateRecitationSessionRequestDto(
    int SurahNumber,
    DateTimeOffset StartedAt,
    int DurationSeconds,
    int VersesMatched,
    int VersesAttempted,
    double AverageConfidence,
    IReadOnlyCollection<string> CoveredRefs);

/// <summary>
/// The reciter's onboarding answers, as the app stores them.
/// </summary>
/// <remarks>
/// The names are the app's enum names, passed through rather than translated,
/// so adding an option is a change in one place. Unknown values are kept as
/// given: an older server must not silently drop an answer a newer app sent.
/// </remarks>
public sealed record ReciterProfileDto(
    string? Extent,
    string? Difficulty,
    IReadOnlyCollection<string> FrequentlyRecited,
    string? Goal,
    DateTimeOffset? CompletedAt);

/// <summary>One reciter's standing.</summary>
/// <remarks>
/// <paramref name="IsCurrentUser"/> is computed server-side so the app does not
/// have to know its own id to highlight the right row.
/// </remarks>
public sealed record LeaderboardEntryDto(
    int Rank,
    Guid UserId,
    string DisplayName,
    int Streak,
    int TotalXp,
    int ReviewedToday,
    bool IsCurrentUser);

/// <summary>
/// A page of the board, plus the caller's own row whatever their rank — so the
/// app can pin it without paging through to find them.
/// </summary>
public sealed record LeaderboardDto(
    IReadOnlyList<LeaderboardEntryDto> Entries,
    LeaderboardEntryDto? CurrentUser);

/// <summary>Follows another reciter by the address they signed up with.</summary>
public sealed record AddFriendRequest(string? Email);
