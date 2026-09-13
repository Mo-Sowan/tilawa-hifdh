using Tilawa.Api.Models;

namespace Tilawa.Api.Services;

/// <summary>Mirrors reciter_profile.dart and plan_preferences.dart; unknown answers retain defaults.</summary>
public static class ReciterPreferences
{
    public static int MaxPlanSurahs(string? extent) => extent switch
    {
        "justStarting" => 3,
        "upToFiveJuz" => 10,
        "halfTheQuran" => 20,
        _ => 40,
    };

    public static IReadOnlySet<int>? PersonalRecitationHabits(ReciterProfile? profile)
    {
        var surahs = new HashSet<int>();
        foreach (var choice in (profile?.FrequentlyRecited ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            switch (choice)
            {
                case "alKahf": surahs.Add(18); break;
                case "yaseen": surahs.Add(36); break;
                case "alMulk": surahs.Add(67); break;
                case "juzAmma": surahs.UnionWith(Enumerable.Range(78, 37)); break;
            }
        }
        return surahs.Count == 0 ? null : surahs;
    }
}
