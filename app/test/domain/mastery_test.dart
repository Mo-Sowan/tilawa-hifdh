import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/domain/entities/mastery.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';
import 'package:tilawa/domain/entities/surah_difficulty.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';

/// These assertions mirror `backend/Tilawa.Api.Tests/MasteryModelTests.cs`.
/// The two implementations must agree, so a change here needs the same change
/// there.
void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  group('a review reflects what the reciter reported', () {
    test('a perfect first review is full mastery', () {
      expect(
        MasteryModel.afterReview(
          currentMastery: 0,
          confidence: 10,
          previousRevisionCount: 0,
        ),
        1.0,
      );
    });

    test('a first review lands on the reported confidence', () {
      for (final entry in {1: 0.1, 5: 0.5, 8: 0.8, 10: 1.0}.entries) {
        expect(
          MasteryModel.afterReview(
            currentMastery: 0,
            confidence: entry.key,
            previousRevisionCount: 0,
          ),
          closeTo(entry.value, 1e-9),
          reason: 'confidence ${entry.key}',
        );
      }
    });

    test('a perfect review is always full mastery, however faded', () {
      expect(
        MasteryModel.afterReview(
          currentMastery: 0.2,
          confidence: 10,
          previousRevisionCount: 12,
        ),
        closeTo(1.0, 1e-9),
      );
    });

    test('a weak review pulls mastery down without erasing history', () {
      final after = MasteryModel.afterReview(
        currentMastery: 1.0,
        confidence: 3,
        previousRevisionCount: 5,
      );

      expect(after, lessThan(1.0));
      expect(after, greaterThan(0.3));
    });

    test('confidence is clamped to the supported range', () {
      expect(
        MasteryModel.afterReview(
          currentMastery: 0,
          confidence: 99,
          previousRevisionCount: 0,
        ),
        closeTo(1.0, 1e-9),
      );
      expect(
        MasteryModel.afterReview(
          currentMastery: 0,
          confidence: -5,
          previousRevisionCount: 0,
        ),
        closeTo(0.1, 1e-9),
      );
    });
  });

  group('mastery fades between reviews', () {
    test('is unchanged at the moment of review', () {
      expect(
        MasteryModel.current(
          masteryAtReview: 1.0,
          lastReviewed: now,
          consecutiveGoodReviews: 1,
          now: now,
        ),
        closeTo(1.0, 1e-9),
      );
    });

    test('halves after one half-life', () {
      expect(
        MasteryModel.current(
          masteryAtReview: 1.0,
          lastReviewed:
              now.subtract(Duration(days: MasteryModel.baseHalfLifeDays.toInt())),
          consecutiveGoodReviews: 1,
          now: now,
        ),
        closeTo(0.5, 1e-3),
      );
    });

    test('keeps falling the longer it is left', () {
      double after(int days) => MasteryModel.current(
            masteryAtReview: 1.0,
            lastReviewed: now.subtract(Duration(days: days)),
            consecutiveGoodReviews: 1,
            now: now,
          );

      expect(after(30), lessThan(after(7)));
      expect(after(30), lessThan(0.1));
    });

    test('repeated good recalls make mastery hold longer', () {
      double after(int streak) => MasteryModel.current(
            masteryAtReview: 1.0,
            lastReviewed: now.subtract(const Duration(days: 14)),
            consecutiveGoodReviews: streak,
            now: now,
          );

      expect(after(5), greaterThan(after(1)));
    });

    test('the half-life grows with the streak but is capped', () {
      expect(MasteryModel.halfLifeDays(1), MasteryModel.baseHalfLifeDays);
      expect(
        MasteryModel.halfLifeDays(3),
        greaterThan(MasteryModel.halfLifeDays(2)),
      );
      expect(MasteryModel.halfLifeDays(50), MasteryModel.maxHalfLifeDays);
    });

    test('a surah never reviewed has no mastery', () {
      expect(
        MasteryModel.current(
          masteryAtReview: 0.9,
          lastReviewed: null,
          consecutiveGoodReviews: 3,
          now: now,
        ),
        0,
      );
    });

    test('a clock-skewed future review does not inflate mastery', () {
      expect(
        MasteryModel.current(
          masteryAtReview: 0.8,
          lastReviewed: now.add(const Duration(days: 5)),
          consecutiveGoodReviews: 1,
          now: now,
        ),
        closeTo(0.8, 1e-9),
      );
    });
  });

  group('streak and mistakes', () {
    test('a good recall extends the streak and a poor one resets it', () {
      expect(
        MasteryModel.consecutiveGoodAfterReview(
          currentStreak: 3,
          confidence: MasteryModel.successConfidence,
        ),
        4,
      );
      expect(
        MasteryModel.consecutiveGoodAfterReview(
          currentStreak: 3,
          confidence: MasteryModel.successConfidence - 1,
        ),
        0,
      );
    });

    test('a perfect recall leaves no mistake rate', () {
      expect(
        MasteryModel.mistakeRateAfterReview(
          currentMistakeRate: 0,
          confidence: 10,
        ),
        closeTo(0, 1e-9),
      );
    });

    test('mistakes decay on success rather than resetting', () {
      final after = MasteryModel.mistakeRateAfterReview(
        currentMistakeRate: 0.5,
        confidence: 10,
      );

      expect(after, lessThan(0.5));
      expect(after, greaterThan(0));
    });

    test('a failed recall raises the mistake rate', () {
      expect(
        MasteryModel.mistakeRateAfterReview(
          currentMistakeRate: 0.1,
          confidence: 2,
        ),
        greaterThan(
          MasteryModel.mistakeRateAfterReview(
            currentMistakeRate: 0.1,
            confidence: 10,
          ),
        ),
      );
    });
  });

  group('SurahRevision', () {
    SurahRevision withHistory({
      required double masteryAtReview,
      required Duration ago,
      int streak = 1,
    }) {
      // Aal-Imran carries no difficulty adjustment, so these assertions test
      // the base decay curve rather than a coefficient. SurahDifficulty has
      // its own group below.
      return SurahRevision(
        number: 3,
        englishName: 'Aal-Imran',
        arabicName: 'آل عمران',
        juzNumber: 3,
        ayahCount: 4,
        masteryAtReview: masteryAtReview,
        mistakeRate: 0,
        revisionCount: 1,
        consecutiveGoodReviews: streak,
        lastReviewed: DateTime.now().subtract(ago),
        revisionIntensity: RevisionIntensity.light,
        lastRevisionDurationSeconds: 60,
        quranReadCount: 0,
      );
    }

    test('reports the decayed value, not the stored one', () {
      final surah = withHistory(
        masteryAtReview: 1.0,
        ago: const Duration(days: 7),
      );

      expect(surah.masteryAtReview, 1.0);
      expect(surah.mastery, closeTo(0.5, 0.02));
      expect(surah.masteryDecayed, closeTo(0.5, 0.02));
    });

    test('a surah left alone long enough falls due', () {
      final fresh =
          withHistory(masteryAtReview: 1.0, ago: const Duration(hours: 1));
      final neglected =
          withHistory(masteryAtReview: 1.0, ago: const Duration(days: 60));

      expect(fresh.isDueToday, isFalse);
      expect(neglected.isDueToday, isTrue);
    });

    test('an unreviewed surah has no mastery and is due', () {
      final untouched = SurahRevision.empty(112, 'Al-Ikhlaas');

      expect(untouched.mastery, 0);
      expect(untouched.isDueToday, isTrue);
    });
  });

  group('SurahDifficulty', () {
    test('the long mutashabihat surahs fade faster', () {
      for (final surah in const [2, 4, 5, 6]) {
        expect(SurahDifficulty.coefficientFor(surah),
            SurahDifficulty.hardCoefficient);
        expect(SurahDifficulty.isHard(surah), isTrue);
      }
    });

    test('the habitually recited surahs hold longer', () {
      for (final surah in const [18, 36, 67, 78, 100, 114]) {
        expect(SurahDifficulty.coefficientFor(surah),
            SurahDifficulty.easyCoefficient);
        expect(SurahDifficulty.isFrequentlyRecited(surah), isTrue);
      }
    });

    test('everything else is left alone', () {
      for (final surah in const [1, 3, 10, 50, 77]) {
        expect(SurahDifficulty.coefficientFor(surah),
            SurahDifficulty.neutralCoefficient);
      }
    });

    test('a hard surah halves sooner than a neutral one', () {
      final hard = MasteryModel.halfLifeDays(1,
          decayCoefficient: SurahDifficulty.hardCoefficient);
      final neutral = MasteryModel.halfLifeDays(1);
      final easy = MasteryModel.halfLifeDays(1,
          decayCoefficient: SurahDifficulty.easyCoefficient);

      expect(hard, lessThan(neutral));
      expect(easy, greaterThan(neutral));
      // 1.5x the decay rate is two thirds of the half-life.
      expect(hard, closeTo(neutral / 1.5, 1e-9));
      expect(easy, closeTo(neutral * 2, 1e-9));
    });

    test('after the same gap, Al-Baqarah has faded further than An-Naba', () {
      final reviewed = DateTime(2026, 1, 1);
      final now = reviewed.add(const Duration(days: 7));

      double masteryFor(int surah) => MasteryModel.current(
            masteryAtReview: 1,
            lastReviewed: reviewed,
            consecutiveGoodReviews: 1,
            decayCoefficient: SurahDifficulty.coefficientFor(surah),
            now: now,
          );

      final baqarah = masteryFor(2);
      final naba = masteryFor(78);
      final neutral = masteryFor(3);

      expect(baqarah, lessThan(neutral));
      expect(neutral, lessThan(naba));
    });

    test('a hard surah comes due before an easy one', () {
      SurahRevision at(int number, Duration ago) => SurahRevision(
            number: number,
            englishName: '',
            arabicName: '',
            juzNumber: 1,
            ayahCount: 1,
            masteryAtReview: 1,
            mistakeRate: 0,
            revisionCount: 1,
            consecutiveGoodReviews: 1,
            lastReviewed: DateTime.now().subtract(ago),
            revisionIntensity: RevisionIntensity.light,
            lastRevisionDurationSeconds: 0,
            quranReadCount: 0,
          );

      // Five days on: Al-Baqarah has dropped below the threshold, An-Naba has
      // barely moved.
      expect(at(2, const Duration(days: 5)).isDueToday, isTrue);
      expect(at(78, const Duration(days: 5)).isDueToday, isFalse);
    });
  });
}
