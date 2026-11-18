using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

/// <summary>
/// Freezing by the client in the app: plans of six months or longer, three times per year of the plan,
/// up to 30 days each. Staff follow the same rules.
/// </summary>
[Collection(ApiCollection.Name)]
public class FreezeRulesTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private async Task<(HttpClient Admin, HttpClient Client, MembershipDto Membership)> ClientWithPlanAsync(int days)
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin, days);
        var (client, _) = await _s.RegisterClientAsync();
        var res = await _s.AssignAsync(admin, await _s.ClientIdAsync(client), plan.Id);
        res.EnsureSuccessStatusCode();
        return (admin, client, (await res.Content.ReadFromJsonAsync<MembershipDto>(Json))!);
    }

    private static Task<HttpResponseMessage> FreezeAsync(HttpClient http, string prefix, Guid id, DateOnly from, DateOnly to) =>
        http.PostAsJsonAsync($"{prefix}/{id}/freeze", new { startDate = from, endDate = to }, Json);

    [Theory]
    [InlineData(30, 0)]
    [InlineData(179, 0)]
    [InlineData(180, 3)]
    [InlineData(365, 3)]
    [InlineData(366, 6)]
    [InlineData(730, 6)]
    public void Three_freezes_per_year_of_the_plan_and_none_below_six_months(int planDays, int allowed) =>
        Assert.Equal(allowed, MembershipService.FreezesAllowed(planDays));

    [Fact]
    public async Task Memberships_shorter_than_six_months_cannot_be_frozen_by_the_client_or_staff()
    {
        var (admin, client, m) = await ClientWithPlanAsync(90);
        Assert.Equal(0, m.FreezesAllowed);
        var today = Scenario.Today(factory);
        Assert.Equal("freeze_not_available", await Scenario.ErrorCodeAsync(await FreezeAsync(client, "/api/me/memberships", m.Id, today, today.AddDays(3))));
        Assert.Equal("freeze_not_available", await Scenario.ErrorCodeAsync(await FreezeAsync(admin, "/api/admin/memberships", m.Id, today, today.AddDays(3))));
    }

    [Fact]
    public async Task Client_freezes_own_membership_up_to_30_days_three_times_then_the_limit_is_reached()
    {
        var (_, client, m) = await ClientWithPlanAsync(180);
        Assert.Equal(3, m.FreezesAllowed);
        Assert.Equal(0, m.FreezesUsed);
        var saved = factory.Clock.Now;
        try
        {
            var today = Scenario.Today(factory);
            Assert.Equal("freeze_too_long", await Scenario.ErrorCodeAsync(await FreezeAsync(client, "/api/me/memberships", m.Id, today, today.AddDays(30))));

            var end = m.EndDate;
            for (var i = 1; i <= 3; i++)
            {
                var day = Scenario.Today(factory);
                var res = await FreezeAsync(client, "/api/me/memberships", m.Id, day, day.AddDays(1));
                Assert.Equal(HttpStatusCode.OK, res.StatusCode);
                var frozen = (await res.Content.ReadFromJsonAsync<MembershipDto>(Json))!;
                Assert.Equal(MembershipEffectiveStatus.Frozen, frozen.EffectiveStatus);
                Assert.Equal(i, frozen.FreezesUsed);
                end = end.AddDays(2);
                Assert.Equal(end, frozen.EndDate);
                factory.Clock.Now = factory.Clock.Now.AddDays(3); // the freeze is over
            }

            var next = Scenario.Today(factory);
            Assert.Equal("freeze_limit_reached", await Scenario.ErrorCodeAsync(await FreezeAsync(client, "/api/me/memberships", m.Id, next, next.AddDays(1))));
            var shown = (await client.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json))!.Single();
            Assert.Equal((3, 3), (shown.FreezesAllowed, shown.FreezesUsed));
            // The client froze it themselves: no notification about it.
            var notes = await client.GetFromJsonAsync<PagedResult<NotificationDto>>("/api/notifications", Json);
            Assert.DoesNotContain(notes!.Items, n => n.Type == NotificationType.MembershipFrozen);
        }
        finally { factory.Clock.Now = saved; }
    }

    [Fact]
    public async Task A_planned_freeze_cancelled_by_the_client_gives_the_days_back_and_does_not_count()
    {
        var (_, client, m) = await ClientWithPlanAsync(365);
        var today = Scenario.Today(factory);
        var planned = (await (await FreezeAsync(client, "/api/me/memberships", m.Id, today.AddDays(5), today.AddDays(34))).Content
            .ReadFromJsonAsync<MembershipDto>(Json))!;
        Assert.Equal(MembershipEffectiveStatus.Active, planned.EffectiveStatus);
        Assert.Equal(m.EndDate.AddDays(30), planned.EndDate);
        Assert.Equal(1, planned.FreezesUsed);

        var res = await client.PostAsync($"/api/me/memberships/{m.Id}/unfreeze", null);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var back = (await res.Content.ReadFromJsonAsync<MembershipDto>(Json))!;
        Assert.Equal(m.EndDate, back.EndDate);
        Assert.Equal(0, back.FreezesUsed);
        Assert.Null(back.FreezeStartDate);
    }

    [Fact]
    public async Task Client_cannot_freeze_someone_elses_membership()
    {
        var (_, _, other) = await ClientWithPlanAsync(180);
        var (stranger, _) = await _s.RegisterClientAsync();
        var today = Scenario.Today(factory);
        Assert.Equal(HttpStatusCode.NotFound, (await FreezeAsync(stranger, "/api/me/memberships", other.Id, today, today.AddDays(2))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PostAsync($"/api/me/memberships/{other.Id}/unfreeze", null)).StatusCode);
    }

    [Fact]
    public async Task Staff_freeze_follows_the_same_limits_and_notifies_the_client()
    {
        var (admin, client, m) = await ClientWithPlanAsync(180);
        var today = Scenario.Today(factory);
        Assert.Equal("freeze_too_long", await Scenario.ErrorCodeAsync(await FreezeAsync(admin, "/api/admin/memberships", m.Id, today, today.AddDays(31))));
        (await FreezeAsync(admin, "/api/admin/memberships", m.Id, today, today.AddDays(29))).EnsureSuccessStatusCode();
        var notes = await client.GetFromJsonAsync<PagedResult<NotificationDto>>("/api/notifications", Json);
        Assert.Contains(notes!.Items, n => n.Type == NotificationType.MembershipFrozen);
    }
}
