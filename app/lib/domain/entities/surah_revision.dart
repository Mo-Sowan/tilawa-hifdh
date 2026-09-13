import 'package:tilawa/domain/entities/mastery.dart';
import 'package:tilawa/domain/entities/surah_difficulty.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';

/// One surah's revision state for the signed-in reciter.
class SurahRevision {
  const SurahRevision({
    required this.number,
    required this.englishName,
    required this.arabicName,
    required this.juzNumber,
    required this.ayahCount,
    required this.masteryAtReview,
    required this.mistakeRate,
    required this.revisionCount,
    required this.consecutiveGoodReviews,
    required this.lastReviewed,
    required this.revisionIntensity,
    required this.lastRevisionDurationSeconds,
    this.lastRevisionSection,
    required this.quranReadCount,
    this.personalFrequentlyRecited,
  });

  final int number;
  final String englishName;
  final String arabicName;

  /// The juz this surah starts in. Stored as the number so each language
  /// can label it its own way rather than carrying an English string.
  final int juzNumber;
  final int ayahCount;

  /// Mastery as it stood at the end of the last review.
  ///
  /// Read [mastery] for the value to show: memorisation fades, so the stored
  /// number is a starting point rather than the current truth.
  final double masteryAtReview;

  final double mistakeRate;
  final int revisionCount;

  /// Successful recalls in a row. Drives how long mastery holds before it
  /// needs another pass.
  final int consecutiveGoodReviews;

  final DateTime? lastReviewed;
  final RevisionIntensity revisionIntensity;
  final int lastRevisionDurationSeconds;
  final String? lastRevisionSection;
  final int quranReadCount;
  final Set<int>? personalFrequentlyRecited;

  /// How fast this surah fades relative to an average one. See
  /// [SurahDifficulty].
  double get decayCoefficient => SurahDifficulty.coefficientFor(number,
      personalFrequentlyRecited: personalFrequentlyRecited);

  /// Mastery right now, faded by the time since the last review.
  double get mastery => MasteryModel.current(
        masteryAtReview: masteryAtReview,
        lastReviewed: lastReviewed,
        consecutiveGoodReviews: consecutiveGoodReviews,
        decayCoefficient: decayCoefficient,
      );

  /// Days this surah holds before half of what was recalled is gone.
  double get halfLifeDays => MasteryModel.halfLifeDays(
        consecutiveGoodReviews,
        decayCoefficient: decayCoefficient,
      );

  /// How much has been lost since the last review, 0-1.
  double get masteryDecayed => (masteryAtReview - mastery).clamp(0.0, 1.0);

  /// Whether anything is known about how well this surah is held.
  ///
  /// Before the first review there is no evidence either way, so mastery is
  /// absent rather than zero — showing 0% would tell the reciter they have
  /// forgotten something they may never have set out to memorise.
  bool get isAssessed => revisionCount > 0;

  /// Mastery to show, or null while nothing is known yet.
  double? get masteryOrNull => isAssessed ? mastery : null;

  bool get isUnlocked => revisionCount > 0 || number >= 108;

  bool get isWeak => isAssessed && (mistakeRate >= .28 || mastery < .58);

  /// Whether this surah wants revising today.
  ///
  /// Driven by what mastery has decayed to rather than by a fixed ladder of
  /// days, so the schedule follows the same curve the number on screen does.
  /// That is what makes a hard surah come round sooner: its half-life is
  /// shorter, so it crosses the threshold earlier without any separate rule.
  static const double dueBelowMastery = 0.65;

  bool get isDueToday {
    if (lastReviewed == null) return true;
    if (mastery < dueBelowMastery) return true;

    // A surah still above the threshold is left alone unless it has been
    // untouched for a full half-life, which catches the case where a very
    // strong recall would otherwise park it for months.
    final daysSince = DateTime.now().difference(lastReviewed!).inMilliseconds /
        Duration.millisecondsPerDay;
    return daysSince >= halfLifeDays;
  }

  int get xpValue => (mastery * 120).round() + revisionCount * 8;

  factory SurahRevision.empty(int number, String name) {
    return SurahRevision(
      number: number,
      englishName: name,
      arabicName: name,
      juzNumber: 1,
      ayahCount: 0,
      masteryAtReview: 0,
      mistakeRate: 0,
      revisionCount: 0,
      consecutiveGoodReviews: 0,
      lastReviewed: null,
      revisionIntensity: RevisionIntensity.light,
      lastRevisionDurationSeconds: 0,
      lastRevisionSection: null,
      quranReadCount: 0,
    );
  }

  SurahRevision copyWith({
    double? masteryAtReview,
    double? mistakeRate,
    int? revisionCount,
    int? consecutiveGoodReviews,
    DateTime? lastReviewed,
    RevisionIntensity? revisionIntensity,
    int? lastRevisionDurationSeconds,
    String? lastRevisionSection,
    int? quranReadCount,
    Set<int>? personalFrequentlyRecited,
  }) {
    return SurahRevision(
      number: number,
      englishName: englishName,
      arabicName: arabicName,
      juzNumber: juzNumber,
      ayahCount: ayahCount,
      masteryAtReview: masteryAtReview ?? this.masteryAtReview,
      mistakeRate: mistakeRate ?? this.mistakeRate,
      revisionCount: revisionCount ?? this.revisionCount,
      consecutiveGoodReviews:
          consecutiveGoodReviews ?? this.consecutiveGoodReviews,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      revisionIntensity: revisionIntensity ?? this.revisionIntensity,
      lastRevisionDurationSeconds:
          lastRevisionDurationSeconds ?? this.lastRevisionDurationSeconds,
      lastRevisionSection: lastRevisionSection ?? this.lastRevisionSection,
      quranReadCount: quranReadCount ?? this.quranReadCount,
      personalFrequentlyRecited:
          personalFrequentlyRecited ?? this.personalFrequentlyRecited,
    );
  }
}
