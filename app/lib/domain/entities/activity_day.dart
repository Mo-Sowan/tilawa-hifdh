class ActivityDay {
  const ActivityDay({
    required this.date,
    required this.revisionCount,
    required this.xp,
    required this.score,
    required this.surahNumbers,
    required this.durationSeconds,
    required this.quranReadCount,
  });

  final DateTime date;
  final int revisionCount;
  final int xp;
  final int score;
  final Set<int> surahNumbers;
  final int durationSeconds;
  final int quranReadCount;

  bool get hasActivity => revisionCount > 0 || xp > 0 || score > 0 || durationSeconds > 0 || quranReadCount > 0;

  int get minutesSpent => durationSeconds ~/ 60;

  /// Weight of a minute spent, against a surah reviewed.
  ///
  /// Time alone is a poor measure — an hour with the Mushaf open is not an
  /// hour of revision — so getting through a surah counts for ten times a
  /// minute. The heatmap shades by this rather than by raw minutes, so a short
  /// focused session reads as the work it was.
  static const double minuteWeight = 1.0;
  static const double surahWeight = 10.0;

  /// What this day is shaded by.
  double get weightedScore =>
      minutesSpent * minuteWeight + surahNumbers.length * surahWeight;

  /// Which of the five heat tiers this day falls in, 0 (nothing) to 4.
  ///
  /// The thresholds are absolute rather than relative to the user's best day,
  /// so the grid means the same thing in week one as in year two.
  int get heatTier {
    final score = weightedScore;
    if (score <= 0) return 0;
    if (score < 15) return 1;
    if (score < 35) return 2;
    if (score < 70) return 3;
    return 4;
  }

  factory ActivityDay.empty(DateTime date) {
    return ActivityDay(
      date: date,
      revisionCount: 0,
      xp: 0,
      score: 0,
      surahNumbers: {},
      durationSeconds: 0,
      quranReadCount: 0,
    );
  }

  ActivityDay copyWith({
    DateTime? date,
    int? revisionCount,
    int? xp,
    int? score,
    Set<int>? surahNumbers,
    int? durationSeconds,
    int? quranReadCount,
  }) {
    return ActivityDay(
      date: date ?? this.date,
      revisionCount: revisionCount ?? this.revisionCount,
      xp: xp ?? this.xp,
      score: score ?? this.score,
      surahNumbers: surahNumbers ?? this.surahNumbers,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      quranReadCount: quranReadCount ?? this.quranReadCount,
    );
  }
}
