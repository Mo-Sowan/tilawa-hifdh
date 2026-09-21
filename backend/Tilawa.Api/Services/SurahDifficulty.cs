namespace Tilawa.Api.Services;

/// <summary>
/// How fast a surah fades, relative to an average one.
/// </summary>
/// <remarks>
/// <para>
/// Three layers, each overriding the one before. <b>Measured:</b> every surah is
/// scored from the text — bulk, mean verse length, and the share of five-word
/// runs that recur elsewhere in the Quran, which is the <em>mutashabihat</em>
/// that make a hafiz lose their place. <c>tools/build_surah_difficulty.py</c>
/// does the measuring and writes <see cref="SurahDifficultyTable"/>.
/// <b>Curated:</b> a few surahs stand apart for reasons the text cannot show —
/// Al-Fatiha is in every rak'ah, Al-Kahf on Fridays, Al-Mulk before sleep,
/// Yaseen and Juz Amma constantly. <b>Personal:</b> what the reciter says they
/// recite beats any assumption about people in general.
/// </para>
/// <para>
/// The coefficient divides the half-life: above 1 the surah halves sooner;
/// below 1 it holds longer.
/// </para>
/// <para>
/// No curated "hard" list is kept. Measurement reproduces the four surahs that
/// used to be listed by hand — Al-Baqarah, An-Nisa, Al-Ma'idah and Al-An'am all
/// reach the top tier on their own. A test asserts it rather than duplicating
/// the data.
/// </para>
/// <para>
/// The app applies the same rules in <c>surah_difficulty.dart</c>. The two must
/// stay in step — change one, change the other, and update both test suites.
/// </para>
/// </remarks>
public static class SurahDifficulty
{
    /// <summary>
    /// Tier coefficients, from the surah that holds longest to the one that
    /// fades fastest. Indexed by <see cref="SurahDifficultyTable.TierBySurah"/>.
    /// </summary>
    public static readonly IReadOnlyList<double> TierCoefficients =
        new[] { 0.5, 0.75, 1.0, 1.25, 1.5 };

    /// <summary>The tier a surah falls in when nothing is known about it.</summary>
    public const int DefaultTier = 2;

    public const double EasiestCoefficient = 0.5;
    public const double NeutralCoefficient = 1.0;
    public const double HardestCoefficient = 1.5;

    public const int JuzAmmaFirstSurah = 78;
    public const int JuzAmmaLastSurah = 114;

    /// <summary>Surahs carried by habit rather than by revision.</summary>
    public static readonly IReadOnlySet<int> FrequentlyRecitedSurahs = new HashSet<int>
    {
        1,  // Al-Fatiha — every rak'ah of every prayer
        18, // Al-Kahf — Fridays
        36, // Yaseen
        67, // Al-Mulk — before sleep
    };

    /// <summary>The tier this surah's text alone puts it in.</summary>
    public static int MeasuredTier(int surahNumber) =>
        SurahDifficultyTable.TierBySurah.TryGetValue(surahNumber, out var tier)
            ? tier
            : DefaultTier;

    /// <summary>What the text alone says, before any habit is considered.</summary>
    public static double MeasuredCoefficient(int surahNumber) =>
        TierCoefficients[MeasuredTier(surahNumber)];

    /// <summary>Whether the population at large rehearses this surah anyway.</summary>
    public static bool IsHabituallyRecited(int surahNumber) =>
        FrequentlyRecitedSurahs.Contains(surahNumber) ||
        (surahNumber >= JuzAmmaFirstSurah && surahNumber <= JuzAmmaLastSurah);

    /// <summary>
    /// The multiplier applied to this surah's decay rate. Once the reciter has
    /// told us what they actually recite, that replaces the assumption about
    /// what people in general recite — including for the curated list.
    /// </summary>
    public static double CoefficientFor(
        int surahNumber,
        IReadOnlySet<int>? personalFrequentlyRecited = null)
    {
        if (personalFrequentlyRecited is not null)
        {
            return personalFrequentlyRecited.Contains(surahNumber)
                ? EasiestCoefficient
                : MeasuredCoefficient(surahNumber);
        }

        return IsHabituallyRecited(surahNumber)
            ? EasiestCoefficient
            : MeasuredCoefficient(surahNumber);
    }

    /// <summary>Whether this surah decays faster than average.</summary>
    public static bool IsHard(int surahNumber) =>
        CoefficientFor(surahNumber) > NeutralCoefficient;

    /// <summary>Whether this surah holds longer than average.</summary>
    public static bool IsFrequentlyRecited(int surahNumber) =>
        CoefficientFor(surahNumber) < NeutralCoefficient;
}
