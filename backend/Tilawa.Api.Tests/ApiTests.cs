using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Tilawa.Api.DTOs;
using Xunit;

namespace Tilawa.Api.Tests;

public sealed class ApiTests : IClassFixture<TilawaApiFactory>
{
    private readonly TilawaApiFactory _factory;

    public ApiTests(TilawaApiFactory factory)
    {
        _factory = factory;
    }

    // --- Health ------------------------------------------------------------

    [Fact]
    public async Task Health_is_anonymous()
    {
        var response = await _factory.CreateClient().GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // --- Auth --------------------------------------------------------------

    [Fact]
    public async Task Revision_endpoints_reject_anonymous_callers()
    {
        var client = _factory.CreateClient();

        foreach (var path in new[]
                 {
                     "/api/v1/revision/surahs",
                     "/api/v1/revision/progress",
                     "/api/v1/revision/plans",
                     "/api/v1/recitation/sessions",
                 })
        {
            var response = await client.GetAsync(path);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
    }

    [Fact]
    public async Task Sign_in_with_a_rejected_token_returns_401()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync(
            "/api/v1/auth/google",
            new SignInRequestDto(FakeIdentityTokenVerifier.InvalidToken));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Sign_in_with_an_empty_token_returns_400()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync(
            "/api/v1/auth/google",
            new SignInRequestDto(string.Empty));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Signing_in_twice_reuses_the_same_account()
    {
        var client = _factory.CreateClient();

        var first = await SignInAsync(client, "stable-user");
        var second = await SignInAsync(client, "stable-user");

        Assert.Equal(first.User.Id, second.User.Id);
        Assert.NotEqual(first.RefreshToken, second.RefreshToken);
    }

    [Fact]
    public async Task Google_and_apple_subjects_are_separate_accounts()
    {
        var client = _factory.CreateClient();

        var google = await SignInAsync(client, "same-name", provider: "google");
        var apple = await SignInAsync(client, "same-name", provider: "apple");

        Assert.NotEqual(google.User.Id, apple.User.Id);
        Assert.Equal("google", google.User.Provider);
        Assert.Equal("apple", apple.User.Provider);
    }

    [Fact]
    public async Task Refresh_rotates_the_token_and_the_old_one_stops_working()
    {
        var client = _factory.CreateClient();
        var session = await SignInAsync(client, "refresher");

        var refreshed = await client.PostAsJsonAsync(
            "/api/v1/auth/refresh",
            new RefreshRequestDto(session.RefreshToken));
        refreshed.EnsureSuccessStatusCode();

        var replayed = await client.PostAsJsonAsync(
            "/api/v1/auth/refresh",
            new RefreshRequestDto(session.RefreshToken));
        Assert.Equal(HttpStatusCode.Unauthorized, replayed.StatusCode);
    }

    [Fact]
    public async Task Sign_out_revokes_the_refresh_token()
    {
        var client = _factory.CreateClient();
        var session = await SignInAsync(client, "leaver");

        var signOut = await client.PostAsJsonAsync(
            "/api/v1/auth/sign-out",
            new RefreshRequestDto(session.RefreshToken));
        Assert.Equal(HttpStatusCode.NoContent, signOut.StatusCode);

        var refreshed = await client.PostAsJsonAsync(
            "/api/v1/auth/refresh",
            new RefreshRequestDto(session.RefreshToken));
        Assert.Equal(HttpStatusCode.Unauthorized, refreshed.StatusCode);
    }

    // --- Revision ----------------------------------------------------------

    [Fact]
    public async Task Surah_catalogue_covers_all_114()
    {
        var client = await AuthenticatedClientAsync("catalogue");

        var surahs = await client.GetFromJsonAsync<List<SurahRevisionDto>>(
            "/api/v1/revision/surahs");

        Assert.NotNull(surahs);
        Assert.Equal(114, surahs!.Count);
        Assert.Equal(1, surahs[0].Number);
        Assert.Equal(114, surahs[^1].Number);
        Assert.Equal(7, surahs[0].AyahCount);
        Assert.All(surahs, s => Assert.False(string.IsNullOrWhiteSpace(s.ArabicName)));
    }

    [Fact]
    public async Task A_new_account_has_no_priority_surah()
    {
        var client = await AuthenticatedClientAsync("fresh-account");
        var response = await client.GetAsync("/api/v1/revision/priority");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Self_assessment_raises_mastery_and_sets_the_priority_surah()
    {
        var client = await AuthenticatedClientAsync("assessor");

        var response = await client.PostAsJsonAsync(
            "/api/v1/revision/self-assessments",
            new SelfAssessmentRequestDto(112, 9, 300, "Ayahs 1-4", 1));
        response.EnsureSuccessStatusCode();

        var surahs = (await response.Content.ReadFromJsonAsync<List<SurahRevisionDto>>())!;
        var assessed = surahs.Single(s => s.Number == 112);
        // A first review reports the confidence itself, not a fraction of it.
        Assert.Equal(0.9, assessed.MasteryAtReview, 3);
        Assert.Equal(0.9, assessed.Mastery, 2);
        Assert.Equal(1, assessed.RevisionCount);
        Assert.Equal(1, assessed.ConsecutiveGoodReviews);
        Assert.Equal(300, assessed.LastRevisionDurationSeconds);
        Assert.Equal("Light", assessed.RevisionIntensity);
        Assert.NotNull(assessed.LastReviewed);

        var priority = await client.GetFromJsonAsync<SurahRevisionDto>(
            "/api/v1/revision/priority");
        Assert.Equal(112, priority!.Number);
    }

    [Fact]
    public async Task A_perfect_first_review_reads_as_full_mastery()
    {
        var client = await AuthenticatedClientAsync("perfect-recall");

        var response = await client.PostAsJsonAsync(
            "/api/v1/revision/self-assessments",
            new SelfAssessmentRequestDto(113, 10, 120, null, 0));
        response.EnsureSuccessStatusCode();

        var surahs = (await response.Content.ReadFromJsonAsync<List<SurahRevisionDto>>())!;
        var assessed = surahs.Single(s => s.Number == 113);

        Assert.Equal(1.0, assessed.MasteryAtReview, 3);
        Assert.Equal(1.0, assessed.Mastery, 2);
        Assert.Equal(0, assessed.MistakeRate, 3);
    }

    [Fact]
    public async Task Self_assessment_rejects_an_out_of_range_confidence()
    {
        var client = await AuthenticatedClientAsync("bad-confidence");
        var response = await client.PostAsJsonAsync(
            "/api/v1/revision/self-assessments",
            new SelfAssessmentRequestDto(1, 11, 60, null, 0));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Self_assessment_rejects_an_unknown_surah()
    {
        var client = await AuthenticatedClientAsync("bad-surah");
        var response = await client.PostAsJsonAsync(
            "/api/v1/revision/self-assessments",
            new SelfAssessmentRequestDto(200, 5, 60, null, 0));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Progress_reflects_a_recorded_assessment()
    {
        var client = await AuthenticatedClientAsync("progress-user");

        await client.PostAsJsonAsync(
            "/api/v1/revision/self-assessments",
            new SelfAssessmentRequestDto(114, 8, 120, null, 0));

        var progress = await client.GetFromJsonAsync<ProgressSummaryDto>(
            "/api/v1/revision/progress");

        Assert.NotNull(progress);
        Assert.Equal(1, progress!.Streak);
        Assert.Equal(1, progress.ReviewedToday);
        Assert.True(progress.TotalXp > 0);
        Assert.Equal(114, progress.MasteryBuckets.Sum(b => b.Count));
    }

    [Fact]
    public async Task One_account_never_sees_another_accounts_progress()
    {
        var alice = await AuthenticatedClientAsync("alice");
        var bob = await AuthenticatedClientAsync("bob");

        await alice.PostAsJsonAsync(
            "/api/v1/revision/self-assessments",
            new SelfAssessmentRequestDto(103, 10, 90, null, 0));

        var bobSurahs = (await bob.GetFromJsonAsync<List<SurahRevisionDto>>(
            "/api/v1/revision/surahs"))!;
        Assert.Equal(0, bobSurahs.Single(s => s.Number == 103).RevisionCount);

        var bobPriority = await bob.GetAsync("/api/v1/revision/priority");
        Assert.Equal(HttpStatusCode.NotFound, bobPriority.StatusCode);
    }

    // --- Plans -------------------------------------------------------------

    [Fact]
    public async Task Plans_can_be_created_listed_updated_and_deleted()
    {
        var client = await AuthenticatedClientAsync("planner");

        var created = await client.PostAsJsonAsync(
            "/api/v1/revision/plans",
            new CreateRevisionPlanRequestDto(
                "Juz Amma",
                [78, 79, 80],
                DateTimeOffset.UtcNow,
                true));
        created.EnsureSuccessStatusCode();
        var plan = (await created.Content.ReadFromJsonAsync<RevisionPlanDto>())!;
        Assert.Equal(new[] { 78, 79, 80 }, plan.SurahNumbers);

        var listed = (await client.GetFromJsonAsync<List<RevisionPlanDto>>(
            "/api/v1/revision/plans"))!;
        Assert.Single(listed);

        var updated = await client.PutAsJsonAsync(
            $"/api/v1/revision/plans/{plan.Id}",
            new UpdateRevisionPlanRequestDto(
                "Juz Amma - short",
                [112, 113, 114],
                plan.ReminderTime,
                false));
        updated.EnsureSuccessStatusCode();
        var afterUpdate = (await updated.Content.ReadFromJsonAsync<RevisionPlanDto>())!;
        Assert.Equal("Juz Amma - short", afterUpdate.Name);
        Assert.False(afterUpdate.IsActive);

        var deleted = await client.DeleteAsync($"/api/v1/revision/plans/{plan.Id}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var afterDelete = (await client.GetFromJsonAsync<List<RevisionPlanDto>>(
            "/api/v1/revision/plans"))!;
        Assert.Empty(afterDelete);
    }

    [Fact]
    public async Task A_plan_may_contain_any_surah_from_1_to_114()
    {
        var client = await AuthenticatedClientAsync("full-range-planner");

        var created = await client.PostAsJsonAsync(
            "/api/v1/revision/plans",
            new CreateRevisionPlanRequestDto(
                "Openings",
                [1, 2, 36],
                DateTimeOffset.UtcNow,
                true));

        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
    }

    [Theory]
    [InlineData("", new[] { 1 })]
    [InlineData("Empty", new int[0])]
    [InlineData("Out of range", new[] { 115 })]
    public async Task Invalid_plans_are_rejected(string name, int[] surahs)
    {
        var client = await AuthenticatedClientAsync($"plan-validation-{name.Length}-{surahs.Length}");

        var response = await client.PostAsJsonAsync(
            "/api/v1/revision/plans",
            new CreateRevisionPlanRequestDto(name, surahs, DateTimeOffset.UtcNow, true));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task A_plan_belonging_to_another_account_is_not_found()
    {
        var owner = await AuthenticatedClientAsync("plan-owner");
        var stranger = await AuthenticatedClientAsync("plan-stranger");

        var created = await owner.PostAsJsonAsync(
            "/api/v1/revision/plans",
            new CreateRevisionPlanRequestDto("Mine", [1], DateTimeOffset.UtcNow, true));
        var plan = (await created.Content.ReadFromJsonAsync<RevisionPlanDto>())!;

        var deleted = await stranger.DeleteAsync($"/api/v1/revision/plans/{plan.Id}");
        Assert.Equal(HttpStatusCode.NotFound, deleted.StatusCode);
    }

    // --- Recitation --------------------------------------------------------

    [Fact]
    public async Task Recitation_sessions_round_trip()
    {
        var client = await AuthenticatedClientAsync("reciter");

        var created = await client.PostAsJsonAsync(
            "/api/v1/recitation/sessions",
            new CreateRecitationSessionRequestDto(
                SurahNumber: 112,
                StartedAt: DateTimeOffset.UtcNow.AddMinutes(-3),
                DurationSeconds: 180,
                VersesMatched: 4,
                VersesAttempted: 4,
                AverageConfidence: 0.93,
                CoveredRefs: ["112:1", "112:2", "112:3", "112:4"]));
        created.EnsureSuccessStatusCode();

        var sessions = (await client.GetFromJsonAsync<List<RecitationSessionDto>>(
            "/api/v1/recitation/sessions"))!;

        var session = Assert.Single(sessions);
        Assert.Equal(112, session.SurahNumber);
        Assert.Equal(4, session.VersesMatched);
        Assert.Equal(0.93, session.AverageConfidence, 3);
        Assert.Equal(4, session.CoveredRefs.Count);
    }

    [Fact]
    public async Task Recitation_confidence_is_clamped_to_a_probability()
    {
        var client = await AuthenticatedClientAsync("over-confident");

        var created = await client.PostAsJsonAsync(
            "/api/v1/recitation/sessions",
            new CreateRecitationSessionRequestDto(
                SurahNumber: 1,
                StartedAt: DateTimeOffset.UtcNow,
                DurationSeconds: 10,
                VersesMatched: 1,
                VersesAttempted: 1,
                AverageConfidence: 4.2,
                CoveredRefs: ["1:1"]));

        var session = (await created.Content.ReadFromJsonAsync<RecitationSessionDto>())!;
        Assert.Equal(1.0, session.AverageConfidence);
    }

    [Fact]
    public async Task Recitation_sessions_are_scoped_to_their_account()
    {
        var owner = await AuthenticatedClientAsync("session-owner");
        var stranger = await AuthenticatedClientAsync("session-stranger");

        await owner.PostAsJsonAsync(
            "/api/v1/recitation/sessions",
            new CreateRecitationSessionRequestDto(
                1, DateTimeOffset.UtcNow, 10, 1, 1, 0.5, ["1:1"]));

        var strangerSessions = (await stranger.GetFromJsonAsync<List<RecitationSessionDto>>(
            "/api/v1/recitation/sessions"))!;
        Assert.Empty(strangerSessions);
    }

    // --- Mushaf ------------------------------------------------------------

    [Theory]
    [InlineData(0)]
    [InlineData(605)]
    public async Task Mushaf_rejects_page_numbers_outside_the_book(int page)
    {
        var response = await _factory.CreateClient().GetAsync($"/api/v1/mushaf/page/{page}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    // --- Helpers -----------------------------------------------------------

    private async Task<AuthSessionDto> SignInAsync(
        HttpClient client,
        string subject,
        string provider = "google")
    {
        var response = await client.PostAsJsonAsync(
            $"/api/v1/auth/{provider}",
            new SignInRequestDto(subject));

        // Surface the server's own message: a bare 500 tells us nothing.
        Assert.True(
            response.IsSuccessStatusCode,
            $"Sign-in failed with {(int)response.StatusCode}: " +
            await response.Content.ReadAsStringAsync());

        return (await response.Content.ReadFromJsonAsync<AuthSessionDto>())!;
    }

    /// <summary>A client already carrying a bearer token for [subject].</summary>
    private async Task<HttpClient> AuthenticatedClientAsync(string subject)
    {
        var client = _factory.CreateClient();
        var session = await SignInAsync(client, subject);
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", session.AccessToken);
        return client;
    }
}
