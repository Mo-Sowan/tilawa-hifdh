/// What the reciter told us about themselves when they first opened the app.
///
/// Extent and difficulty shape suggested plans; recitation habits adjust
/// mastery decay. The revision goal is retained for future recommendations.
///
/// Every question is skippable, so every field is nullable. A profile with
/// nothing answered is valid and simply means the app has no reason to prefer
/// one default over another.
library;

/// How much of the Quran is held.
enum MemorisationExtent {
  justStarting,
  upToFiveJuz,
  halfTheQuran,
  entireQuran;

  static MemorisationExtent? fromName(String? name) =>
      name == null ? null : values.where((v) => v.name == name).firstOrNull;
}

/// What gets in the way.
enum MemorisationDifficulty {
  longSurahs,
  mutashabihat,
  stayingConsistent,
  motivation;

  static MemorisationDifficulty? fromName(String? name) =>
      name == null ? null : values.where((v) => v.name == name).firstOrNull;
}

/// What is recited most often. More than one answer is expected here.
enum FrequentlyRecited {
  alKahf(18),
  yaseen(36),
  alMulk(67),
  juzAmma(78);

  const FrequentlyRecited(this.surahNumber);

  /// The surah this stands for. For [juzAmma] it is the first of the run.
  final int surahNumber;

  static FrequentlyRecited? fromName(String? name) =>
      name == null ? null : values.where((v) => v.name == name).firstOrNull;
}

/// Why they are here.
enum RevisionGoal {
  buildDailyHabit,
  retainMemorised,
  memoriseNew,
  prepareForTests;

  static RevisionGoal? fromName(String? name) =>
      name == null ? null : values.where((v) => v.name == name).firstOrNull;
}

class ReciterProfile {
  const ReciterProfile({
    this.extent,
    this.difficulty,
    this.frequentlyRecited = const {},
    this.goal,
    this.completedAt,
  });

  final MemorisationExtent? extent;
  final MemorisationDifficulty? difficulty;
  final Set<FrequentlyRecited> frequentlyRecited;
  final RevisionGoal? goal;

  /// When the questionnaire was finished. Null means it has not been, which is
  /// what decides whether a returning reciter is asked again.
  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  // An empty selection cannot distinguish a skipped question from "none".
  Set<int>? get personalRecitationHabits =>
      frequentlyRecited.isEmpty ? null : frequentlyRecitedSurahs;

  bool get hasAnyAnswer =>
      extent != null ||
      difficulty != null ||
      frequentlyRecited.isNotEmpty ||
      goal != null;

  /// Surahs the reciter says they recite often, expanded to surah numbers.
  ///
  /// Juz Amma is the whole run, not just its first surah, because that is what
  /// someone means when they pick it.
  Set<int> get frequentlyRecitedSurahs => {
        for (final choice in frequentlyRecited)
          if (choice == FrequentlyRecited.juzAmma)
            for (var number = 78; number <= 114; number++) number
          else
            choice.surahNumber,
      };

  ReciterProfile copyWith({
    MemorisationExtent? extent,
    MemorisationDifficulty? difficulty,
    Set<FrequentlyRecited>? frequentlyRecited,
    RevisionGoal? goal,
    DateTime? completedAt,
  }) {
    return ReciterProfile(
      extent: extent ?? this.extent,
      difficulty: difficulty ?? this.difficulty,
      frequentlyRecited: frequentlyRecited ?? this.frequentlyRecited,
      goal: goal ?? this.goal,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'extent': extent?.name,
        'difficulty': difficulty?.name,
        'frequentlyRecited': frequentlyRecited.map((c) => c.name).toList(),
        'goal': goal?.name,
        'completedAt': completedAt?.toIso8601String(),
      };

  static ReciterProfile fromJson(Map<String, Object?> json) {
    final recited = json['frequentlyRecited'];
    final completedAt = json['completedAt'] as String?;

    return ReciterProfile(
      extent: MemorisationExtent.fromName(json['extent'] as String?),
      difficulty:
          MemorisationDifficulty.fromName(json['difficulty'] as String?),
      frequentlyRecited: {
        if (recited is List)
          for (final name in recited)
            if (FrequentlyRecited.fromName(name as String?) case final choice?)
              choice,
      },
      goal: RevisionGoal.fromName(json['goal'] as String?),
      completedAt: completedAt == null ? null : DateTime.tryParse(completedAt),
    );
  }
}
