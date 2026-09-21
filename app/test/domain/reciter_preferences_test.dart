import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/domain/entities/mastery.dart';
import 'package:tilawa/domain/entities/plan_preferences.dart';
import 'package:tilawa/domain/entities/reciter_profile.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';
import 'package:tilawa/domain/entities/surah_difficulty.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';

SurahRevision surah(int number, int verses, {bool assessed = false}) =>
    SurahRevision(
      number: number,
      englishName: '$number',
      arabicName: '$number',
      juzNumber: 1,
      ayahCount: verses,
      masteryAtReview: .8,
      mistakeRate: 0,
      revisionCount: assessed ? 1 : 0,
      consecutiveGoodReviews: 0,
      lastReviewed: DateTime.now().subtract(const Duration(days: 5)),
      revisionIntensity: RevisionIntensity.light,
      lastRevisionDurationSeconds: 0,
      quranReadCount: 0,
    );

void main() {
  // Shared policy assertions mirror ReciterPreferencesTests.cs.
  test('personal habit wins even over a hard surah', () {
    // Named by the reciter: holds longest, whatever the text says.
    expect(SurahDifficulty.coefficientFor(2, personalFrequentlyRecited: {2}),
        SurahDifficulty.easiestCoefficient);

    // Not named: the measurement stands, and the curated assumption that
    // everyone reads Al-Kahf on a Friday no longer applies to this reciter.
    for (final surah in const [18, 4, 114]) {
      expect(
        SurahDifficulty.coefficientFor(surah, personalFrequentlyRecited: {2}),
        SurahDifficulty.measuredCoefficient(surah),
        reason: 'surah $surah',
      );
    }

    // With nothing stated, the curated assumption does apply.
    expect(SurahDifficulty.coefficientFor(18),
        SurahDifficulty.easiestCoefficient);
  });
  test('profile choices expand Juz Amma and skipped answers retain defaults',
      () {
    const profile = ReciterProfile(frequentlyRecited: {
      FrequentlyRecited.alKahf,
      FrequentlyRecited.juzAmma
    });
    expect(profile.personalRecitationHabits,
        {18, for (var i = 78; i <= 114; i++) i});
    expect(const ReciterProfile().personalRecitationHabits, isNull);
    expect(
        ReciterProfile.fromJson({
          'frequentlyRecited': ['futureChoice']
        }).personalRecitationHabits,
        isNull);
  });
  test('extent caps mirror the API', () {
    expect(PlanPreferences.maxSurahs(MemorisationExtent.justStarting), 3);
    expect(PlanPreferences.maxSurahs(MemorisationExtent.upToFiveJuz), 10);
    expect(PlanPreferences.maxSurahs(MemorisationExtent.halfTheQuran), 20);
    expect(PlanPreferences.maxSurahs(MemorisationExtent.entireQuran), 40);
    expect(PlanPreferences.maxSurahs(null), 40);
  });
  test('shorter known surahs come first when long surahs are difficult', () {
    final selected = PlanPreferences.defaultSelection(
        const ReciterProfile(
          extent: MemorisationExtent.justStarting,
          difficulty: MemorisationDifficulty.longSurahs,
        ),
        [
          surah(2, 286, assessed: true),
          surah(3, 200, assessed: true),
          surah(4, 176, assessed: true),
          surah(5, 120, assessed: true),
          surah(114, 6)
        ]);
    expect(selected.toList(), [5, 4, 3]);
  });
  test('no answers leave manual selection empty; extent never hides catalogue',
      () {
    final catalogue = [
      surah(2, 286),
      surah(18, 110),
      surah(114, 6),
      surah(113, 5)
    ];
    expect(PlanPreferences.defaultSelection(const ReciterProfile(), catalogue),
        isEmpty);
    expect(
        PlanPreferences.defaultSelection(
            const ReciterProfile(extent: MemorisationExtent.justStarting),
            catalogue),
        {113, 114, 18});
    expect(catalogue.map((s) => s.number), [2, 18, 114, 113]);
    expect(
        () => PlanPreferences.validateSize({1, 2, 3, 4}, 3), throwsStateError);
    expect(() => PlanPreferences.validateSize({}, 3), throwsStateError);
  });
  test(
      'personal coefficient reaches decay, due date and subsequent review input',
      () {
    final original = surah(18, 110, assessed: true);
    final personal = original.copyWith(personalFrequentlyRecited: {67});
    expect(personal.decayCoefficient, 1);
    expect(personal.halfLifeDays, original.halfLifeDays / 2);
    expect(personal.mastery, lessThan(original.mastery));
    expect(personal.isDueToday, isTrue);
    expect(
        MasteryModel.afterReview(
            currentMastery: personal.mastery,
            confidence: 8,
            previousRevisionCount: 1),
        lessThan(MasteryModel.afterReview(
            currentMastery: original.mastery,
            confidence: 8,
            previousRevisionCount: 1)));
  });
}
