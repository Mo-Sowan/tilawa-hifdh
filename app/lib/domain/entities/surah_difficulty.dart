/// How fast a surah fades, relative to an average one.
///
/// Not every surah is held the same way. Two things move the needle, and they
/// pull in opposite directions:
///
/// * **Length and *mutashabihat*.** The long Madani surahs repeat near-identical
///   passages with small differences in wording and order, which is precisely
///   what memory blurs first. Huffaz consistently name Al-Baqarah, An-Nisa,
///   Al-Ma'idah and Al-An'am as the ones that slip fastest.
/// * **Habitual recitation.** Al-Kahf on Fridays, Al-Mulk before sleep, Yaseen,
///   and the short surahs of Juz Amma in daily prayer are all rehearsed without
///   anyone calling it revision, so they hold far longer than the schedule
///   would otherwise assume.
///
/// The coefficient divides the half-life: above 1 the surah halves sooner and
/// comes back around for revision more often; below 1 it holds longer and the
/// plan leaves it alone. An unlisted surah is 1.0 and behaves exactly as
/// before, so this only ever adjusts the cases there is a reason to adjust.
///
/// The API applies the same table in `SurahDifficulty.cs`. The two must stay in
/// step — change one, change the other, and update both test suites.
class SurahDifficulty {
  const SurahDifficulty._();

  /// The default: no adjustment either way.
  static const double neutralCoefficient = 1.0;

  /// Long, and dense with near-repeated passages.
  static const double hardCoefficient = 1.5;

  /// Recited often enough to be rehearsed outside revision.
  static const double easyCoefficient = 0.5;

  /// Surahs that fade fastest: length plus *mutashabihat*.
  static const Set<int> hardSurahs = {
    2, // Al-Baqarah
    4, // An-Nisa
    5, // Al-Ma'idah
    6, // Al-An'am
  };

  /// Surahs carried by habit outside of revision.
  static const Set<int> frequentlyRecitedSurahs = {
    18, // Al-Kahf — Fridays
    36, // Yaseen
    67, // Al-Mulk — before sleep
  };

  /// Juz Amma, recited in daily prayer.
  static const int juzAmmaFirstSurah = 78;
  static const int juzAmmaLastSurah = 114;

  /// The multiplier applied to this surah's decay rate.
  static double coefficientFor(int surahNumber,
      {Set<int>? personalFrequentlyRecited}) {
    if (personalFrequentlyRecited != null) {
      if (personalFrequentlyRecited.contains(surahNumber)) {
        return easyCoefficient;
      }
      return hardSurahs.contains(surahNumber)
          ? hardCoefficient
          : neutralCoefficient;
    }
    if (hardSurahs.contains(surahNumber)) return hardCoefficient;
    if (frequentlyRecitedSurahs.contains(surahNumber)) return easyCoefficient;
    if (surahNumber >= juzAmmaFirstSurah && surahNumber <= juzAmmaLastSurah) {
      return easyCoefficient;
    }
    return neutralCoefficient;
  }

  /// Whether this surah decays faster than average.
  static bool isHard(int surahNumber) =>
      coefficientFor(surahNumber) > neutralCoefficient;

  /// Whether this surah holds longer than average.
  static bool isFrequentlyRecited(int surahNumber) =>
      coefficientFor(surahNumber) < neutralCoefficient;
}
