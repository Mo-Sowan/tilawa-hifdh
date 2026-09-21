using Tilawa.Api.Services;
using Xunit;

namespace Tilawa.Api.Tests;

/// <summary>
/// These assertions mirror `app/test/domain/mastery_test.dart`. The two
/// implementations must agree, so a change here needs the same change there.
/// </summary>
public class MasteryModelTests
{
    private static readonly DateTimeOffset Now = new(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);

    // --- A review reflects what the reciter reported ------------------------

    [Fact]
    public void A_perfect_first_review_is_full_mastery()
    {
        Assert.Equal(1.0, MasteryModel.AfterReview(0, 10, previousRevisionCount: 0));
    }

    [Theory]
    [InlineData(1, 0.1)]
    [InlineData(5, 0.5)]
    [InlineData(8, 0.8)]
    [InlineData(10, 1.0)]
    public void A_first_review_lands_on_the_reported_confidence(int confidence, double expected)
    {
        Assert.Equal(expected, MasteryModel.AfterReview(0, confidence, 0), 6);
    }

    [Fact]
    public void A_perfect_review_is_always_full_mastery_however_faded()
    {
        Assert.Equal(1.0, MasteryModel.AfterReview(0.2, 10, previousRevisionCount: 12), 6);
    }

    [Fact]
    public void A_weak_review_pulls_mastery_down_without_erasing_history()
    {
        // Was solid, recalled it badly: mastery drops, but not all the way to
        // the weak score.
        var after = MasteryModel.AfterReview(1.0, 3, previousRevisionCount: 5);

        Assert.True(after < 1.0);
        Assert.True(after > 0.3);
    }

    [Fact]
    public void Confidence_is_clamped_to_the_supported_range()
    {
        Assert.Equal(1.0, MasteryModel.AfterReview(0, 99, 0), 6);
        Assert.Equal(0.1, MasteryModel.AfterReview(0, -5, 0), 6);
    }

    // --- Mastery fades between reviews --------------------------------------

    [Fact]
    public void Mastery_is_unchanged_at_the_moment_of_review()
    {
        Assert.Equal(1.0, MasteryModel.Current(1.0, Now, 1, now: Now), 6);
    }

    [Fact]
    public void Mastery_halves_after_one_half_life()
    {
        var reviewed = Now.AddDays(-MasteryModel.BaseHalfLifeDays);

        Assert.Equal(0.5, MasteryModel.Current(1.0, reviewed, 1, now: Now), 3);
    }

    [Fact]
    public void Mastery_keeps_falling_the_longer_it_is_left()
    {
        var week = MasteryModel.Current(1.0, Now.AddDays(-7), 1, now: Now);
        var month = MasteryModel.Current(1.0, Now.AddDays(-30), 1, now: Now);

        Assert.True(month < week);
        Assert.True(month < 0.1);
    }

    [Fact]
    public void Repeated_good_recalls_make_mastery_hold_longer()
    {
        var once = MasteryModel.Current(1.0, Now.AddDays(-14), 1, now: Now);
        var fiveTimes = MasteryModel.Current(1.0, Now.AddDays(-14), 5, now: Now);

        Assert.True(fiveTimes > once);
    }

    [Fact]
    public void The_half_life_grows_with_the_streak_but_is_capped()
    {
        Assert.Equal(MasteryModel.BaseHalfLifeDays, MasteryModel.HalfLifeDays(1), 6);
        Assert.True(MasteryModel.HalfLifeDays(3) > MasteryModel.HalfLifeDays(2));
        Assert.Equal(MasteryModel.MaxHalfLifeDays, MasteryModel.HalfLifeDays(50), 6);
    }

    [Fact]
    public void A_surah_never_reviewed_has_no_mastery()
    {
        Assert.Equal(0, MasteryModel.Current(0.9, null, 3, now: Now));
    }

    [Fact]
    public void A_clock_skewed_future_review_does_not_inflate_mastery()
    {
        Assert.Equal(0.8, MasteryModel.Current(0.8, Now.AddDays(5), 1, now: Now), 6);
    }

    // --- Streak and mistakes ------------------------------------------------

    [Fact]
    public void A_good_recall_extends_the_streak_and_a_poor_one_resets_it()
    {
        Assert.Equal(4, MasteryModel.ConsecutiveGoodAfterReview(3, MasteryModel.SuccessConfidence));
        Assert.Equal(0, MasteryModel.ConsecutiveGoodAfterReview(3, MasteryModel.SuccessConfidence - 1));
    }

    [Fact]
    public void A_perfect_recall_leaves_no_mistake_rate()
    {
        Assert.Equal(0, MasteryModel.MistakeRateAfterReview(0, 10), 6);
    }

    [Fact]
    public void Mistakes_decay_on_success_rather_than_resetting()
    {
        var after = MasteryModel.MistakeRateAfterReview(0.5, 10);

        Assert.True(after < 0.5);
        Assert.True(after > 0);
    }

    [Fact]
    public void A_failed_recall_raises_the_mistake_rate()
    {
        Assert.True(
            MasteryModel.MistakeRateAfterReview(0.1, 2) >
            MasteryModel.MistakeRateAfterReview(0.1, 10));
    }

    // This is the claim that replaced a hand-written "hard surahs" list: the
    // four every hafiz names are found by measuring the text, not by being
    // typed in. If the generator stops reproducing them, this fails.
    [Fact]
    public void MeasurementAlonePutsTheLongMutashabihatSurahsInTheTopTier()
    {
        foreach (var surah in new[] { 2, 4, 5, 6 })
        {
            Assert.Equal(SurahDifficulty.TierCoefficients.Count - 1, SurahDifficulty.MeasuredTier(surah));
            Assert.Equal(SurahDifficulty.HardestCoefficient, SurahDifficulty.CoefficientFor(surah));
            Assert.True(SurahDifficulty.IsHard(surah));
        }
    }

    [Fact]
    public void EverySurahHasATierAndTiersAreOrdered()
    {
        for (var surah = 1; surah <= 114; surah++)
        {
            var tier = SurahDifficulty.MeasuredTier(surah);
            Assert.InRange(tier, 0, 4);
        }

        for (var tier = 1; tier < SurahDifficulty.TierCoefficients.Count; tier++)
        {
            Assert.True(SurahDifficulty.TierCoefficients[tier] > SurahDifficulty.TierCoefficients[tier - 1]);
        }
    }

    [Fact]
    public void HabituallyRecitedSurahsHoldLongest()
    {
        foreach (var surah in new[] { 1, 18, 36, 67, 78, 100, 114 })
        {
            Assert.Equal(SurahDifficulty.EasiestCoefficient, SurahDifficulty.CoefficientFor(surah));
            Assert.True(SurahDifficulty.IsFrequentlyRecited(surah));
        }
    }

    // Al-Kahf, Yaseen and Al-Mulk measure as unremarkable text. They are easy
    // because of when they are recited, not how they read.
    [Fact]
    public void TheCuratedLayerOverridesWhatTheTextAloneWouldSay()
    {
        foreach (var surah in new[] { 18, 36, 67 })
        {
            Assert.Equal(SurahDifficulty.NeutralCoefficient, SurahDifficulty.MeasuredCoefficient(surah));
            Assert.Equal(SurahDifficulty.EasiestCoefficient, SurahDifficulty.CoefficientFor(surah));
        }
    }

    [Fact]
    public void StatedHabitsReplaceTheAssumptionAboutPeopleInGeneral()
    {
        var stated = new HashSet<int> { 2 };

        Assert.Equal(SurahDifficulty.EasiestCoefficient, SurahDifficulty.CoefficientFor(2, stated));

        foreach (var surah in new[] { 18, 4, 114 })
        {
            Assert.Equal(SurahDifficulty.MeasuredCoefficient(surah), SurahDifficulty.CoefficientFor(surah, stated));
        }
    }

    [Fact]
    public void AHardSurahHalvesSoonerThanANeutralOne()
    {
        var hard = MasteryModel.HalfLifeDays(1, SurahDifficulty.HardestCoefficient);
        var neutral = MasteryModel.HalfLifeDays(1);
        var easy = MasteryModel.HalfLifeDays(1, SurahDifficulty.EasiestCoefficient);

        Assert.True(hard < neutral);
        Assert.True(easy > neutral);
        Assert.Equal(neutral / 1.5, hard, 9);
        Assert.Equal(neutral * 2, easy, 9);
    }

    [Fact]
    public void AfterTheSameGapAlBaqarahHasFadedFurtherThanAnNaba()
    {
        var reviewed = Now.AddDays(-7);

        double MasteryFor(int surah) => MasteryModel.Current(
            1.0, reviewed, 1, SurahDifficulty.CoefficientFor(surah), now: Now);

        var baqarah = MasteryFor(2);
        var neutral = MasteryFor(19);
        var naba = MasteryFor(78);

        Assert.True(baqarah < neutral);
        Assert.True(neutral < naba);
    }
}
