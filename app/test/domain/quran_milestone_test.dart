import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/domain/entities/quran_milestone.dart';

/// Every surah from [from] to [to] inclusive.
Set<int> run(int from, int to) => {for (var s = from; s <= to; s++) s};

void main() {
  group('earning a milestone', () {
    test('an unbroken run backwards from An-Nas earns each landmark', () {
      expect(QuranMilestone.quarter.isEarnedBy(run(36, 114)), isTrue);
      expect(QuranMilestone.half.isEarnedBy(run(18, 114)), isTrue);
      expect(QuranMilestone.threeQuarters.isEarnedBy(run(8, 114)), isTrue);
      expect(QuranMilestone.whole.isEarnedBy(run(1, 114)), isTrue);
    });

    test('the landmark surah alone earns nothing', () {
      // The case the rule exists for: reciting Yaseen is not a quarter of the
      // Quran, however often you do it.
      expect(QuranMilestone.quarter.isEarnedBy({36}), isFalse);
      expect(QuranMilestone.half.isEarnedBy({18}), isFalse);
      expect(QuranMilestone.threeQuarters.isEarnedBy({8}), isFalse);
    });

    test('one gap in the run breaks it', () {
      final almost = run(36, 114)..remove(80);
      expect(QuranMilestone.quarter.isEarnedBy(almost), isFalse);
    });

    test('stopping one surah short earns nothing', () {
      expect(QuranMilestone.quarter.isEarnedBy(run(37, 114)), isFalse);
      expect(QuranMilestone.whole.isEarnedBy(run(2, 114)), isFalse);
    });
  });

  group('the half is the only landmark reachable from the front', () {
    test('Al-Fatiha through Al-Kahf earns the half', () {
      expect(QuranMilestone.half.isEarnedBy(run(1, 18)), isTrue);
    });

    test('but the front does not earn the quarter or three quarters', () {
      expect(QuranMilestone.quarter.isEarnedBy(run(1, 36)), isFalse);
      expect(QuranMilestone.threeQuarters.isEarnedBy(run(1, 8)), isFalse);
    });

    test('only the half advertises itself as reachable from the start', () {
      for (final milestone in QuranMilestone.values) {
        expect(
          milestone.isReachableFromStart,
          milestone == QuranMilestone.half,
          reason: milestone.name,
        );
      }
    });
  });

  group('earning one implies the ones before it', () {
    test('the whole Quran earns all four', () {
      expect(QuranMilestone.earnedBy(run(1, 114)), QuranMilestone.values);
    });

    test('three quarters earns the quarter and the half too', () {
      final earned = QuranMilestone.earnedBy(run(8, 114));
      expect(earned, [
        QuranMilestone.quarter,
        QuranMilestone.half,
        QuranMilestone.threeQuarters,
      ]);
    });

    test('nothing revised earns nothing', () {
      expect(QuranMilestone.earnedBy(const {}), isEmpty);
    });
  });

  group('what comes next', () {
    test('points at the first landmark not yet earned', () {
      expect(QuranMilestone.nextAfter(const {}), QuranMilestone.quarter);
      expect(QuranMilestone.nextAfter(run(36, 114)), QuranMilestone.half);
      expect(QuranMilestone.nextAfter(run(8, 114)), QuranMilestone.whole);
    });

    test('is null once the Quran is complete', () {
      expect(QuranMilestone.nextAfter(run(1, 114)), isNull);
    });
  });

  group('progress towards a landmark', () {
    test('runs from nothing to earned', () {
      expect(QuranMilestone.quarter.progressFor(const {}), 0);
      expect(QuranMilestone.quarter.progressFor(run(36, 114)), 1);
    });

    test('counts only surahs inside the run', () {
      // Al-Baqarah is outside the quarter's range, so it moves nothing.
      expect(QuranMilestone.quarter.progressFor({2}), 0);
    });

    test('the half takes whichever direction is further along', () {
      // Six surahs from the front, two from the back.
      final mixed = run(1, 6)..addAll(run(113, 114));
      final forwards = 6 / 18;
      expect(QuranMilestone.half.progressFor(mixed), closeTo(forwards, 1e-9));
    });

    test('progress is monotonic as surahs are added', () {
      final revised = <int>{};
      var previous = 0.0;
      for (var surah = 114; surah >= 36; surah--) {
        revised.add(surah);
        final now = QuranMilestone.quarter.progressFor(revised);
        expect(now, greaterThanOrEqualTo(previous));
        previous = now;
      }
      expect(previous, 1);
    });
  });
}
