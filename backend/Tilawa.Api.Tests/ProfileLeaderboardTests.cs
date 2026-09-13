using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Tilawa.Api.Data;
using Tilawa.Api.DTOs;
using Tilawa.Api.Models;
using Tilawa.Api.Services;
using Xunit;

namespace Tilawa.Api.Tests;

public sealed class ProfileLeaderboardTests
{
    [Fact]
    public async Task EndpointsRequireAuthentication()
    {
        using var factory = new TilawaApiFactory();
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/profile")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PutAsJsonAsync("/api/v1/profile", Profile())).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/leaderboard?scope=global&limit=10")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/v1/leaderboard/friends", new AddFriendRequest("a@b.test"))).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.DeleteAsync($"/api/v1/leaderboard/friends/{Guid.NewGuid()}")).StatusCode);
    }

    [Fact]
    public async Task ProfileRoundTripsReplacesAndIsIsolatedByUser()
    {
        using var factory = new TilawaApiFactory();
        var (alice, _) = await SignIn(factory, "alice");
        var (bob, _) = await SignIn(factory, "bob");
        using (alice) using (bob)
        {
            Assert.Equal(HttpStatusCode.NotFound, (await alice.GetAsync("/api/v1/profile")).StatusCode);
            var profile = Profile();
            (await alice.PutAsJsonAsync("/api/v1/profile", profile)).EnsureSuccessStatusCode();
            var stored = await alice.GetFromJsonAsync<ReciterProfileDto>("/api/v1/profile");
            Assert.Equal(profile.Extent, stored!.Extent);
            Assert.Equal(profile.Difficulty, stored.Difficulty);
            Assert.Equal(profile.FrequentlyRecited, stored.FrequentlyRecited);
            Assert.Equal(profile.Goal, stored.Goal);
            Assert.Equal(profile.CompletedAt, stored.CompletedAt);
            Assert.Equal(HttpStatusCode.NotFound, (await bob.GetAsync("/api/v1/profile")).StatusCode);
            (await alice.PutAsJsonAsync("/api/v1/profile", new ReciterProfileDto(null, null, [], null, null))).EnsureSuccessStatusCode();
            stored = await alice.GetFromJsonAsync<ReciterProfileDto>("/api/v1/profile");
            Assert.Null(stored!.Extent);
            Assert.Empty(stored.FrequentlyRecited);
            Assert.Null(stored.CompletedAt);
        }
    }

    [Fact]
    public async Task RankingsFriendScopeAndPinnedCurrentUserUseActualActivity()
    {
        using var factory = new TilawaApiFactory();
        var (alice, a) = await SignIn(factory, "alice");
        var (bob, b) = await SignIn(factory, "bob");
        var (carol, c) = await SignIn(factory, "carol");
        using (alice) using (bob) using (carol)
        {
            using (var scope = factory.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<TilawaDbContext>();
                var today = DateOnly.FromDateTime(DateTime.UtcNow);
                db.ActivityDays.AddRange(
                    new ActivityDay { UserId = a.User.Id, Date = today, Xp = 10, RevisionCount = 1 },
                    new ActivityDay { UserId = b.User.Id, Date = today, Xp = 100, RevisionCount = 3 },
                    new ActivityDay { UserId = c.User.Id, Date = today, Xp = 100, RevisionCount = 2 });
                await db.SaveChangesAsync();
            }
            var board = await alice.GetFromJsonAsync<LeaderboardDto>("/api/v1/leaderboard?scope=global&limit=1");
            Assert.Single(board!.Entries);
            Assert.Equal(new[] { b.User.Id, c.User.Id }.Order().First(), board.Entries[0].UserId);
            Assert.Equal(100, board.Entries[0].TotalXp);
            Assert.Equal(3, board.CurrentUser!.Rank);
            Assert.True(board.CurrentUser.IsCurrentUser);
            Assert.Equal(1, board.CurrentUser.Streak);
            Assert.Equal(1, board.CurrentUser.ReviewedToday);

            var friend = new AddFriendRequest(" bob@example.test ");
            Assert.Equal(HttpStatusCode.NoContent, (await alice.PostAsJsonAsync("/api/v1/leaderboard/friends", friend)).StatusCode);
            Assert.Equal(HttpStatusCode.NoContent, (await alice.PostAsJsonAsync("/api/v1/leaderboard/friends", friend)).StatusCode);
            board = await alice.GetFromJsonAsync<LeaderboardDto>("/api/v1/leaderboard?scope=friends&limit=10");
            Assert.Equal(new[] { b.User.Id, a.User.Id }, board!.Entries.Select(e => e.UserId));
            var reverse = await bob.GetFromJsonAsync<LeaderboardDto>("/api/v1/leaderboard?scope=friends&limit=10");
            Assert.Single(reverse!.Entries);
            Assert.Equal(b.User.Id, reverse.Entries[0].UserId);
            Assert.Equal(HttpStatusCode.NoContent, (await bob.DeleteAsync($"/api/v1/leaderboard/friends/{b.User.Id}")).StatusCode);
            Assert.Equal(2, (await alice.GetFromJsonAsync<LeaderboardDto>("/api/v1/leaderboard?scope=friends&limit=10"))!.Entries.Count);
            Assert.Equal(HttpStatusCode.NoContent, (await alice.DeleteAsync($"/api/v1/leaderboard/friends/{b.User.Id}")).StatusCode);
            Assert.Equal(HttpStatusCode.NoContent, (await alice.DeleteAsync($"/api/v1/leaderboard/friends/{b.User.Id}")).StatusCode);
            Assert.Single((await alice.GetFromJsonAsync<LeaderboardDto>("/api/v1/leaderboard?scope=friends&limit=10"))!.Entries);
        }
    }

    [Fact]
    public async Task InvalidFriendRequestsAndEmptyBoardAreExplicit()
    {
        using var factory = new TilawaApiFactory();
        var (client, _) = await SignIn(factory, "alice");
        using (client)
        {
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/leaderboard/friends", new AddFriendRequest(" "))).StatusCode);
            var self = await client.PostAsJsonAsync("/api/v1/leaderboard/friends", new AddFriendRequest("alice@example.test"));
            var missing = await client.PostAsJsonAsync("/api/v1/leaderboard/friends", new AddFriendRequest("missing@example.test"));
            Assert.Equal(HttpStatusCode.NotFound, self.StatusCode);
            Assert.Equal(self.StatusCode, missing.StatusCode);
            Assert.Equal(await self.Content.ReadAsStringAsync(), await missing.Content.ReadAsStringAsync());
            var board = await client.GetFromJsonAsync<LeaderboardDto>("/api/v1/leaderboard?scope=global&limit=0");
            Assert.Empty(board!.Entries);
            Assert.Null(board.CurrentUser);
        }
    }

    [Theory]
    [InlineData(new int[] { }, 0)]
    [InlineData(new[] { 0, -1, -2 }, 3)]
    [InlineData(new[] { -1, -2 }, 2)]
    [InlineData(new[] { -2 }, 0)]
    [InlineData(new[] { 0, 0, -1, -3, 1 }, 2)]
    public void StreakHandlesGraceDayGapsDuplicatesAndFutureDates(int[] offsets, int expected)
    {
        var today = new DateOnly(2026, 9, 12);
        Assert.Equal(expected, LeaderboardService.StreakEndingAt(today, offsets.Select(today.AddDays)));
    }

    private static ReciterProfileDto Profile() => new("upToFiveJuz", "longSurahs", ["alMulk", "juzAmma"], "retainMemorised", DateTimeOffset.Parse("2026-09-12T10:00:00Z"));

    internal static async Task<(HttpClient Client, AuthSessionDto Session)> SignIn(TilawaApiFactory factory, string subject)
    {
        var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/v1/auth/google", new SignInRequestDto(subject));
        response.EnsureSuccessStatusCode();
        var session = (await response.Content.ReadFromJsonAsync<AuthSessionDto>())!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);
        return (client, session);
    }
}
