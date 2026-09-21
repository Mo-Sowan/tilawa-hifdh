import 'package:tilawa/domain/entities/surah_difficulty_table.dart';

/// How fast a surah fades, relative to an average one.
///
/// Three layers, each overriding the one before:
///
/// 1. **Measured.** Every surah is scored from the text itself — bulk, mean
///    verse length, and the share of five-word runs that recur elsewhere in the
///    Quran, which is the *mutashabihat* that make a hafiz lose their place.
///    `tools/build_surah_difficulty.py` does the measuring and writes
///    [SurahDifficultyTable]; the evidence for each surah is in a comment on
///    its row.
/// 2. **Curated.** A few surahs stand apart for reasons the text cannot show.
///    Al-Fatiha is recited in every unit of every prayer; Al-Kahf on Fridays,
///    Al-Mulk before sleep, Yaseen and the short surahs of Juz Amma are all
///    rehearsed constantly without anyone calling it revision. Measurement puts
///    Al-Kahf, Yaseen and Al-Mulk in the middle tier, which is right about the
///    text and wrong about the person.
/// 3. **Personal.** What the reciter says they actually recite beats any
///    assumption about what people in general recite.
///
/// The coefficient divides the half-life: above 1 the surah halves sooner and
/// comes round for revision more often; below 1 it holds longer.
///
/// No curated "hard" list is kept. Measurement reproduces the four surahs that
/// used to be listed by hand — Al-Baqarah, An-Nisa, Al-Ma'idah and Al-An'am all
/// land in the top tier on their own — so listing them again would be data
/// duplicated in two places. A test asserts it instead, which is where a claim
/// like that belongs.
///
/// The API applies the same rules in `SurahDifficulty.cs`. The two must stay in
/// step — change one, change the other, and update both test suites.
class SurahDifficulty {
  const SurahDifficulty._();

  /// Tier coefficients, from the surah that holds longest to the one that
  /// fades fastest. Indexed by [SurahDifficultyTable.tierBySurah].
  static const List<double> tierCoefficients = [0.5, 0.75, 1.0, 1.25, 1.5];

  /// The tier a surah falls in when nothing is known about it.
  static const int defaultTier = 2;

  static const double easiestCoefficient = 0.5;
  static const double neutralCoefficient = 1.0;
  static const double hardestCoefficient = 1.5;

  /// Surahs carried by habit rather than by revision.
  static const Set<int> frequentlyRecitedSurahs = {
    1, // Al-Fatiha — every rak'ah of every prayer
    18, // Al-Kahf — Fridays
    36, // Yaseen
    67, // Al-Mulk — before sleep
  };

  /// Juz Amma, recited in daily prayer.
  static const int juzAmmaFirstSurah = 78;
  static const int juzAmmaLastSurah = 114;

  /// The tier this surah's text alone puts it in.
  static int measuredTier(int surahNumber) =>
      SurahDifficultyTable.tierBySurah[surahNumber] ?? defaultTier;

  /// What the text alone says, before any habit is taken into account.
  static double measuredCoefficient(int surahNumber) =>
      tierCoefficients[measuredTier(surahNumber)];

  /// Whether this surah is one the population at large rehearses anyway.
  static bool isHabituallyRecited(int surahNumber) =>
      frequentlyRecitedSurahs.contains(surahNumber) ||
      (surahNumber >= juzAmmaFirstSurah && surahNumber <= juzAmmaLastSurah);

  /// The multiplier applied to this surah's decay rate.
  ///
  /// Once the reciter has told us what they actually recite, that replaces the
  /// assumption about what people in general recite — including for surahs on
  /// the curated list. Someone who never opens Al-Kahf on a Friday should not
  /// have the app quietly assume they do.
  static double coefficientFor(
    int surahNumber, {
    Set<int>? personalFrequentlyRecited,
  }) {
    if (personalFrequentlyRecited != null) {
      return personalFrequentlyRecited.contains(surahNumber)
          ? easiestCoefficient
          : measuredCoefficient(surahNumber);
    }
    return isHabituallyRecited(surahNumber)
        ? easiestCoefficient
        : measuredCoefficient(surahNumber);
  }

  /// Whether this surah decays faster than average.
  static bool isHard(int surahNumber) =>
      coefficientFor(surahNumber) > neutralCoefficient;

  /// Whether this surah holds longer than average.
  static bool isFrequentlyRecited(int surahNumber) =>
      coefficientFor(surahNumber) < neutralCoefficient;
}
