namespace Tilawa.Api.Services;

/// <summary>
/// How fast a surah fades, relative to an average one.
/// </summary>
/// <remarks>
/// <para>
/// Two forces pull in opposite directions. Length and <em>mutashabihat</em>:
/// the long Madani surahs repeat near-identical passages with small differences
/// in wording and order, which is what memory blurs first, and huffaz name
/// Al-Baqarah, An-Nisa, Al-Ma'idah and Al-An'am as the ones that slip fastest.
/// Against that, habitual recitation: Al-Kahf on Fridays, Al-Mulk before sleep,
/// Yaseen, and the short surahs of Juz Amma in daily prayer are rehearsed
/// without anyone calling it revision, so they hold far longer.
/// </para>
/// <para>
/// The coefficient divides the half-life: above 1 the surah halves sooner and
/// comes round for revision more often; below 1 it holds longer. An unlisted
/// surah is 1.0 and behaves exactly as before.
/// </para>
/// <para>
/// The app applies the same table in <c>surah_difficulty.dart</c>. The two must
/// stay in step — change one, change the other, and update both test suites.
/// </para>
/// </remarks>
public static class SurahDifficulty
{
    /// <summary>The default: no adjustment either way.</summary>
    public const double NeutralCoefficient = 1.0;

    /// <summary>Long, and dense with near-repeated passages.</summary>
    public const double HardCoefficient = 1.5;

    /// <summary>Recited often enough to be rehearsed outside revision.</summary>
    public const double EasyCoefficient = 0.5;

    public const int JuzAmmaFirstSurah = 78;
    public const int JuzAmmaLastSurah = 114;

    /// <summary>Surahs that fade fastest: length plus <em>mutashabihat</em>.</summary>
    public static readonly IReadOnlySet<int> HardSurahs = new HashSet<int>
    {
        2, // Al-Baqarah
        4, // An-Nisa
        5, // Al-Ma'idah
        6, // Al-An'am
    };

    /// <summary>Surahs carried by habit outside of revision.</summary>
    public static readonly IReadOnlySet<int> FrequentlyRecitedSurahs = new HashSet<int>
    {
        18, // Al-Kahf — Fridays
        36, // Yaseen
        67, // Al-Mulk — before sleep
    };

    /// <summary>The multiplier applied to this surah's decay rate.</summary>
    public static double CoefficientFor(int surahNumber, IReadOnlySet<int>? personalFrequentlyRecited = null)
    {
        // Explicit habits replace population assumptions, including for otherwise hard surahs.
        if (personalFrequentlyRecited is not null)
        {
            if (personalFrequentlyRecited.Contains(surahNumber)) return EasyCoefficient;
            return HardSurahs.Contains(surahNumber) ? HardCoefficient : NeutralCoefficient;
        }
        if (HardSurahs.Contains(surahNumber)) return HardCoefficient;
        if (FrequentlyRecitedSurahs.Contains(surahNumber)) return EasyCoefficient;
        if (surahNumber >= JuzAmmaFirstSurah && surahNumber <= JuzAmmaLastSurah)
        {
            return EasyCoefficient;
        }
        return NeutralCoefficient;
    }

    /// <summary>Whether this surah decays faster than average.</summary>
    public static bool IsHard(int surahNumber) =>
        CoefficientFor(surahNumber) > NeutralCoefficient;

    /// <summary>Whether this surah holds longer than average.</summary>
    public static bool IsFrequentlyRecited(int surahNumber) =>
        CoefficientFor(surahNumber) < NeutralCoefficient;
}
