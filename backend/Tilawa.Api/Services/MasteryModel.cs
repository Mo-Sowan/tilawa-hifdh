namespace Tilawa.Api.Services;

/// <summary>
/// How well a surah is retained, and how that changes over time.
/// </summary>
/// <remarks>
/// <para>Two rules:</para>
/// <list type="number">
/// <item><description>
/// <b>A review moves mastery toward what the reciter reported.</b> The first
/// review lands on it outright — if you say you recalled it perfectly, you have
/// mastered it — while later reviews blend, so one shaky pass does not erase a
/// long history and one good pass after a lapse does not instantly claim full
/// mastery back.
/// </description></item>
/// <item><description>
/// <b>Mastery decays between reviews.</b> Memorisation fades when it is not
/// revisited, so the stored value is what mastery was <i>at the last review</i>
/// and the current value is that decayed by elapsed time.
/// </description></item>
/// </list>
/// <para>
/// Decay is exponential with a half-life that grows each time the surah is
/// recalled well. That is the spacing effect: the more often you have
/// successfully brought it back, the longer it holds without another pass.
/// </para>
/// <para>
/// The app implements the same rules in <c>domain/entities/mastery.dart</c>.
/// The two must stay in step — change one, change the other, and update both
/// test suites.
/// </para>
/// </remarks>
public static class MasteryModel
{
    /// <summary>A review at or above this confidence counts as a successful recall.</summary>
    public const int SuccessConfidence = 6;

    public const int MinConfidence = 1;
    public const int MaxConfidence = 10;

    /// <summary>Half-life of a surah recalled well once.</summary>
    public const double BaseHalfLifeDays = 7;

    /// <summary>Each further consecutive good recall multiplies the half-life by this.</summary>
    public const double HalfLifeGrowth = 1.8;

    /// <summary>Beyond roughly six months, further growth stops mattering in practice.</summary>
    public const double MaxHalfLifeDays = 180;

    /// <summary>
    /// Floor on how far a single review can move mastery once there is history,
    /// so a very low self-rating still counts for something rather than
    /// overwriting everything.
    /// </summary>
    public const double MinBlendWeight = 0.5;

    /// <summary>
    /// Days a surah holds before its mastery halves.
    /// <paramref name="decayCoefficient"/> divides the result: a surah that
    /// fades fast (1.5) halves in two thirds of the time, one carried by habit
    /// (0.5) takes twice as long. See <see cref="SurahDifficulty"/>.
    /// </summary>
    public static double HalfLifeDays(
        int consecutiveGoodReviews,
        double decayCoefficient = SurahDifficulty.NeutralCoefficient)
    {
        var b = consecutiveGoodReviews <= 0
            ? BaseHalfLifeDays
            : Math.Min(
                BaseHalfLifeDays * Math.Pow(HalfLifeGrowth, consecutiveGoodReviews - 1),
                MaxHalfLifeDays);

        // A coefficient of zero or less would mean "never fades", which no
        // surah does; guard rather than divide by it.
        return decayCoefficient <= 0 ? b : b / decayCoefficient;
    }

    /// <summary>
    /// Mastery right now: <paramref name="masteryAtReview"/> faded by the time
    /// since <paramref name="lastReviewed"/>. Zero for a surah never reviewed.
    /// </summary>
    public static double Current(
        double masteryAtReview,
        DateTimeOffset? lastReviewed,
        int consecutiveGoodReviews,
        double decayCoefficient = SurahDifficulty.NeutralCoefficient,
        DateTimeOffset? now = null)
    {
        if (lastReviewed is null || masteryAtReview <= 0) return 0;

        var elapsed = (now ?? DateTimeOffset.UtcNow) - lastReviewed.Value;
        if (elapsed < TimeSpan.Zero) return Math.Clamp(masteryAtReview, 0, 1);

        var halfLife = HalfLifeDays(consecutiveGoodReviews, decayCoefficient);
        var decay = Math.Pow(0.5, elapsed.TotalDays / halfLife);
        return Math.Clamp(masteryAtReview * decay, 0, 1);
    }

    /// <summary>
    /// Mastery immediately after a review reporting <paramref name="confidence"/>
    /// out of 10. <paramref name="currentMastery"/> is the decayed value going
    /// in, so a surah that has faded is genuinely rebuilt rather than resuming
    /// from where it left off.
    /// </summary>
    public static double AfterReview(
        double currentMastery,
        int confidence,
        int previousRevisionCount)
    {
        var target = Math.Clamp(confidence, MinConfidence, MaxConfidence) / (double)MaxConfidence;

        // Nothing to blend with on a first review: the reported confidence is
        // the mastery.
        if (previousRevisionCount <= 0) return Math.Clamp(target, 0, 1);

        var weight = Math.Max(target, MinBlendWeight);
        return Math.Clamp(currentMastery + (target - currentMastery) * weight, 0, 1);
    }

    /// <summary>
    /// Mistake rate after a review. Decays toward zero on success rather than
    /// resetting, so a history of slips still shows.
    /// </summary>
    public static double MistakeRateAfterReview(double currentMistakeRate, int confidence)
    {
        var failed = confidence < SuccessConfidence;
        return Math.Clamp(currentMistakeRate * 0.9 + (failed ? 0.1 : 0), 0, 1);
    }

    /// <summary>
    /// Consecutive successful recalls after a review, used to grow the
    /// half-life. A failed recall resets the streak.
    /// </summary>
    public static int ConsecutiveGoodAfterReview(int currentStreak, int confidence) =>
        confidence >= SuccessConfidence ? currentStreak + 1 : 0;
}
