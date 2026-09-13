using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Tilawa.Api.Data;
using Tilawa.Api.DTOs;
using Tilawa.Api.Models;
using Tilawa.Api.Services;
using Xunit;

namespace Tilawa.Api.Tests;

public sealed class ReciterPreferencesTests
{
    [Fact]
    public void PersonalHabitsOverrideStaticAssumptions()
    {
        IReadOnlySet<int> habits = new HashSet<int> { 2 };
        Assert.Equal(.5, SurahDifficulty.CoefficientFor(2, habits));
        Assert.Equal(1, SurahDifficulty.CoefficientFor(18, habits));
        Assert.Equal(1.5, SurahDifficulty.CoefficientFor(4, habits));
        Assert.Equal(1, SurahDifficulty.CoefficientFor(114, habits));
        Assert.Equal(.5, SurahDifficulty.CoefficientFor(18));
    }

    [Fact]
    public void ProfileExpansionMatchesDartAndUnknownAnswersKeepDefaults()
    {
        var profile = new ReciterProfile { FrequentlyRecited = "alKahf,juzAmma" };
        Assert.Equal(new[] { 18 }.Concat(Enumerable.Range(78, 37)), ReciterPreferences.PersonalRecitationHabits(profile)!.Order());
        Assert.Null(ReciterPreferences.PersonalRecitationHabits(new ReciterProfile()));
        Assert.Null(ReciterPreferences.PersonalRecitationHabits(new ReciterProfile { FrequentlyRecited = "futureChoice" }));
    }

    [Theory]
    [InlineData("justStarting", 3)]
    [InlineData("upToFiveJuz", 10)]
    [InlineData("halfTheQuran", 20)]
    [InlineData("entireQuran", 40)]
    [InlineData(null, 40)]
    public void ExtentCapsMatchDart(string? extent, int maximum) => Assert.Equal(maximum, ReciterPreferences.MaxPlanSurahs(extent));

    [Fact]
    public async Task SavedProfileChangesApiMasteryAndEnforcesPlanSize()
    {
        using var factory = new TilawaApiFactory();
        var (client, session) = await ProfileLeaderboardTests.SignIn(factory, "personal");
        using (client)
        {
            using (var scope = factory.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<TilawaDbContext>();
                db.UserSurahProgress.Add(new UserSurahProgress
                {
                    UserId = session.User.Id, SurahNumber = 18, Mastery = .8,
                    RevisionCount = 1, LastReviewed = DateTimeOffset.UtcNow.AddDays(-5),
                });
                await db.SaveChangesAsync();
            }
            var before = (await client.GetFromJsonAsync<List<SurahRevisionDto>>("/api/v1/revision/surahs"))!.Single(s => s.Number == 18);
            (await client.PutAsJsonAsync("/api/v1/profile", new ReciterProfileDto("justStarting", "longSurahs", ["alMulk"], null, null))).EnsureSuccessStatusCode();
            var after = (await client.GetFromJsonAsync<List<SurahRevisionDto>>("/api/v1/revision/surahs"))!.Single(s => s.Number == 18);
            Assert.Equal(before.MasteryAtReview, after.MasteryAtReview);
            Assert.True(after.Mastery < before.Mastery);
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/revision/plans",
                new CreateRevisionPlanRequestDto("Too large", [1, 2, 3, 4], DateTimeOffset.UtcNow))).StatusCode);
            var created = await client.PostAsJsonAsync("/api/v1/revision/plans",
                new CreateRevisionPlanRequestDto("Small plan", [1, 2, 3], DateTimeOffset.UtcNow));
            created.EnsureSuccessStatusCode();
            var plan = (await created.Content.ReadFromJsonAsync<RevisionPlanDto>())!;
            Assert.Equal(HttpStatusCode.NotFound, (await client.PutAsJsonAsync($"/api/v1/revision/plans/{plan.Id}",
                new UpdateRevisionPlanRequestDto("Too large", [1, 2, 3, 4], DateTimeOffset.UtcNow, true))).StatusCode);
        }
    }
}
