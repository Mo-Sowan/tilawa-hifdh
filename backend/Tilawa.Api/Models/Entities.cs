namespace Tilawa.Api.Models;

/// <summary>
/// Identity providers the API can verify tokens from.
/// </summary>
public enum AuthProvider
{
    Google = 0,
    Apple = 1
}

/// <summary>
/// A signed-in account.
/// </summary>
/// <remarks>
/// Identity is always federated, so there is no password hash here and never
/// will be. A user is uniquely identified by (provider, provider subject).
/// </remarks>
public sealed class User
{
    public Guid Id { get; init; } = Guid.NewGuid();

    /// <summary>Which provider vouched for this account.</summary>
    public AuthProvider Provider { get; init; }

    /// <summary>The provider's stable subject claim (`sub`).</summary>
    public required string ProviderSubject { get; init; }

    /// <summary>
    /// May be empty: Apple lets users withhold their address, in which case
    /// only the relay or nothing at all is supplied.
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// Apple only sends the name on the very first authorization, so this is
    /// filled once and then preserved.
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;

    public DateTimeOffset LastSignedInAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// What the reciter told us about themselves when they first opened the app.
/// </summary>
/// <remarks>
/// Mirrored from the device rather than owned here: the app works without an
/// account, so the answers have to survive on the phone first. This copy is
/// what lets them follow the reciter to another device. Every answer is
/// optional because every question is skippable.
/// </remarks>
public sealed class ReciterProfile
{
    public Guid UserId { get; init; }

    /// <summary>How much of the Quran is held.</summary>
    public string? Extent { get; set; }

    /// <summary>What gets in the way.</summary>
    public string? Difficulty { get; set; }

    /// <summary>
    /// What is recited most often, as a comma-separated list of names. Stored
    /// flat because it is only ever read and written whole, never queried by
    /// element.
    /// </summary>
    public string FrequentlyRecited { get; set; } = string.Empty;

    /// <summary>Why they are here.</summary>
    public string? Goal { get; set; }

    /// <summary>
    /// When the questionnaire was finished. Null means it was abandoned part
    /// way, and the answers given so far still count.
    /// </summary>
    public DateTimeOffset? CompletedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// A refresh token, stored hashed so a database leak cannot be replayed.
/// </summary>
public sealed class RefreshToken
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public Guid UserId { get; init; }

    /// <summary>SHA-256 of the token that was handed to the client.</summary>
    public required string TokenHash { get; init; }

    public DateTimeOffset ExpiresAt { get; init; }

    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;

    public DateTimeOffset? RevokedAt { get; set; }

    public bool IsActive => RevokedAt is null && DateTimeOffset.UtcNow < ExpiresAt;
}

/// <summary>
/// Static, user-independent metadata for one surah.
/// </summary>
public sealed class Surah
{
    public int Number { get; init; }

    public required string EnglishName { get; set; }

    public required string ArabicName { get; set; }

    public required string JuzLabel { get; set; }

    public required int AyahCount { get; set; }
}

/// <summary>
/// One user's progress on one surah.
/// </summary>
/// <remarks>
/// Rows are created lazily on first assessment, so a new account costs one row
/// rather than 114.
/// </remarks>
public sealed class UserSurahProgress
{
    public Guid UserId { get; init; }

    public int SurahNumber { get; init; }

    /// <summary>
    /// Mastery as it stood at the end of the last review, 0.0-1.0.
    /// </summary>
    /// <remarks>
    /// Not the value to display: memorisation fades, so the current figure is
    /// this decayed by the time since <see cref="LastReviewed"/>. See
    /// <c>MasteryModel</c>.
    /// </remarks>
    public double Mastery { get; set; }

    /// <summary>
    /// Successful recalls in a row. Drives how long mastery holds before it
    /// needs another pass.
    /// </summary>
    public int ConsecutiveGoodReviews { get; set; }

    /// <summary>0.0-1.0: decaying rate of self-reported mistakes.</summary>
    public double MistakeRate { get; set; }

    public int RevisionCount { get; set; }

    public DateTimeOffset? LastReviewed { get; set; }

    /// <summary>"Light" or "Intense" — how hard the next pass should be.</summary>
    public string RevisionIntensity { get; set; } = "Light";

    public int LastRevisionDurationSeconds { get; set; }

    /// <summary>Free text such as "Ayahs 1-10".</summary>
    public string? LastRevisionSection { get; set; }

    /// <summary>Cumulative Mushaf opens while revising this surah.</summary>
    public int QuranReadCount { get; set; }
}

/// <summary>
/// A named set of surahs the user wants to revise, with a daily reminder.
/// </summary>
public sealed class RevisionPlan
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public Guid UserId { get; init; }

    public required string Name { get; set; }

    /// <summary>Stored as a JSON array in SQLite.</summary>
    public HashSet<int> SurahNumbers { get; set; } = [];

    public DateTimeOffset ReminderTime { get; set; }

    public bool IsActive { get; set; }

    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// One user's activity totals for one day, the basis of streaks and XP.
/// </summary>
public sealed class ActivityDay
{
    public Guid UserId { get; init; }

    public DateOnly Date { get; init; }

    public int RevisionCount { get; set; }

    public int Xp { get; set; }

    public int Score { get; set; }

    /// <summary>Stored as a JSON array in SQLite.</summary>
    public HashSet<int> SurahNumbers { get; set; } = [];

    public int DurationSeconds { get; set; }

    public int QuranReadCount { get; set; }
}

/// <summary>
/// One completed offline follow-along session, uploaded after the fact.
/// </summary>
/// <remarks>
/// Only the outcome is stored. Recognition runs entirely on the device and no
/// audio is ever transmitted.
/// </remarks>
public sealed class RecitationSession
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public Guid UserId { get; init; }

    public int SurahNumber { get; init; }

    public DateTimeOffset StartedAt { get; init; }

    public int DurationSeconds { get; init; }

    /// <summary>Ayat the recogniser matched.</summary>
    public int VersesMatched { get; init; }

    /// <summary>Ayat in the range the user set out to recite.</summary>
    public int VersesAttempted { get; init; }

    /// <summary>Mean recognition confidence across the matched ayat, 0.0-1.0.</summary>
    public double AverageConfidence { get; init; }

    /// <summary>Matched references as a JSON array of "surah:ayah" strings.</summary>
    public List<string> CoveredRefs { get; set; } = [];

    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;
}
