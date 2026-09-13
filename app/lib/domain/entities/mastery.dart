import 'dart:math' as math;

import 'package:tilawa/domain/entities/surah_difficulty.dart';

/// How well a surah is retained, and how that changes over time.
///
/// Two rules:
///
/// 1. **A review moves mastery toward what the reciter reported.** The first
///    review lands on it outright — if you say you recalled it perfectly, you
///    have mastered it — while later reviews blend, so one shaky pass does not
///    erase a long history and one good pass after a lapse does not instantly
///    claim full mastery back.
/// 2. **Mastery decays between reviews.** Memorisation fades when it is not
///    revisited, so the stored value is what mastery was *at the last review*
///    and the current value is that decayed by elapsed time.
///
/// Decay is exponential with a half-life that grows each time the surah is
/// recalled well. That is the spacing effect: the more often you have
/// successfully brought it back, the longer it holds without another pass.
///
/// The API implements the same rules in `MasteryModel.cs`. The two must stay
/// in step — change one, change the other, and update both test suites.
class MasteryModel {
  const MasteryModel._();

  /// A review at or above this confidence counts as a successful recall.
  static const int successConfidence = 6;

  static const int minConfidence = 1;
  static const int maxConfidence = 10;

  /// Half-life of a surah recalled well once.
  static const double baseHalfLifeDays = 7;

  /// Each further consecutive good recall multiplies the half-life by this.
  static const double halfLifeGrowth = 1.8;

  /// Beyond roughly six months, further growth stops mattering in practice.
  static const double maxHalfLifeDays = 180;

  /// Floor on how far a single review can move mastery once there is history,
  /// so a very low self-rating still counts for something rather than
  /// overwriting everything.
  static const double minBlendWeight = 0.5;

  /// Days a surah holds before its mastery halves.
  ///
  /// [decayCoefficient] divides the result: a surah that fades fast (1.5)
  /// halves in two thirds of the time, one carried by habit (0.5) takes twice
  /// as long. See [SurahDifficulty] for where the coefficients come from.
  static double halfLifeDays(
    int consecutiveGoodReviews, {
    double decayCoefficient = SurahDifficulty.neutralCoefficient,
  }) {
    final base = consecutiveGoodReviews <= 0
        ? baseHalfLifeDays
        : math.min(
            (baseHalfLifeDays *
                    math.pow(halfLifeGrowth, consecutiveGoodReviews - 1))
                .toDouble(),
            maxHalfLifeDays,
          );

    // A coefficient of zero or less would mean "never fades", which no surah
    // does; guard rather than divide by it.
    if (decayCoefficient <= 0) return base;
    return base / decayCoefficient;
  }

  /// Mastery right now: [masteryAtReview] faded by the time since
  /// [lastReviewed].
  ///
  /// Returns 0 for a surah that has never been reviewed.
  static double current({
    required double masteryAtReview,
    required DateTime? lastReviewed,
    required int consecutiveGoodReviews,
    double decayCoefficient = SurahDifficulty.neutralCoefficient,
    DateTime? now,
  }) {
    if (lastReviewed == null || masteryAtReview <= 0) return 0;

    final elapsed = (now ?? DateTime.now()).difference(lastReviewed);
    if (elapsed.isNegative) return masteryAtReview.clamp(0.0, 1.0);

    final days = elapsed.inMilliseconds / Duration.millisecondsPerDay;
    final halfLife = halfLifeDays(
      consecutiveGoodReviews,
      decayCoefficient: decayCoefficient,
    );
    final decay = math.pow(0.5, days / halfLife).toDouble();
    return (masteryAtReview * decay).clamp(0.0, 1.0);
  }

  /// Mastery immediately after a review reporting [confidence] out of 10.
  ///
  /// [currentMastery] is the decayed value going in, so a surah that has faded
  /// is genuinely rebuilt rather than resuming from where it left off.
  static double afterReview({
    required double currentMastery,
    required int confidence,
    required int previousRevisionCount,
  }) {
    final target =
        confidence.clamp(minConfidence, maxConfidence) / maxConfidence;

    // Nothing to blend with on a first review: the reported confidence is the
    // mastery.
    if (previousRevisionCount <= 0) return target.clamp(0.0, 1.0);

    final weight = math.max(target, minBlendWeight);
    return (currentMastery + (target - currentMastery) * weight)
        .clamp(0.0, 1.0);
  }

  /// Mistake rate after a review. Decays toward zero on success rather than
  /// resetting, so a history of slips still shows.
  static double mistakeRateAfterReview({
    required double currentMistakeRate,
    required int confidence,
  }) {
    final failed = confidence < successConfidence;
    return (currentMistakeRate * 0.9 + (failed ? 0.1 : 0)).clamp(0.0, 1.0);
  }

  /// Consecutive successful recalls after a review, used to grow the
  /// half-life. A failed recall resets the streak.
  static int consecutiveGoodAfterReview({
    required int currentStreak,
    required int confidence,
  }) {
    return confidence >= successConfidence ? currentStreak + 1 : 0;
  }
}
