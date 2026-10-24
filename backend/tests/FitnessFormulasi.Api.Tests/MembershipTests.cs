using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

[Collection(ApiCollection.Name)]
public class MembershipTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    [Fact]
    public async Task Admin_creates_plan_and_assigns_membership_with_inclusive_end_date()
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin, days: 30);
        var (client, _) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);
        var today = Scenario.Today(factory);

        var res = await _s.AssignAsync(admin, clientId, plan.Id);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        var m = (await res.Content.ReadFromJsonAsync<MembershipDto>(Json))!;
        Assert.Equal(today, m.StartDate);
        Assert.Equal(today.AddDays(29), m.EndDate);
        Assert.Equal(MembershipEffectiveStatus.Active, m.EffectiveStatus);
        Assert.Equal(30, m.DaysLeft);

        var mine = await client.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json);
        Assert.Single(mine!);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(m.Id, dash!.CurrentMembership!.Id);
        Assert.True(dash.UnreadNotifications >= 1); // MembershipAssigned
    }

    [Fact]
    public async Task Overlapping_membership_is_rejected_but_consecutive_is_allowed()
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin, days: 30);
        var (client, _) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);
        var today = Scenario.Today(factory);
        (await _s.AssignAsync(admin, clientId, plan.Id, today)).EnsureSuccessStatusCode();

        var overlap = await _s.AssignAsync(admin, clientId, plan.Id, today.AddDays(29));
        Assert.Equal(HttpStatusCode.Conflict, overlap.StatusCode);
        Assert.Equal("membership_overlap", await Scenario.ErrorCodeAsync(overlap));

        var next = await _s.AssignAsync(admin, clientId, plan.Id, today.AddDays(30));
        Assert.Equal(HttpStatusCode.Created, next.StatusCode);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(MembershipEffectiveStatus.Upcoming, dash!.NextMembership!.EffectiveStatus);
    }

    [Fact]
    public async Task Expired_membership_is_not_shown_as_active()
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin, days: 30);
        var (client, _) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);
        (await _s.AssignAsync(admin, clientId, plan.Id, Scenario.Today(factory).AddDays(-30))).EnsureSuccessStatusCode();

        var mine = (await client.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json))!;
        Assert.Equal(MembershipEffectiveStatus.Expired, mine.Single().EffectiveStatus);
        Assert.Equal(0, mine.Single().DaysLeft);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Null(dash!.CurrentMembership);

        var active = await admin.GetFromJsonAsync<PagedResult<MembershipDto>>($"/api/admin/memberships?status=Active&clientId={clientId}", Json);
        Assert.Empty(active!.Items);
        var expired = await admin.GetFromJsonAsync<PagedResult<MembershipDto>>($"/api/admin/memberships?status=Expired&clientId={clientId}", Json);
        Assert.Single(expired!.Items);
    }

    [Fact]
    public async Task Membership_expires_when_club_day_changes()
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin, days: 1);
        var (client, _) = await _s.RegisterClientAsync();
        (await _s.AssignAsync(admin, await _s.ClientIdAsync(client), plan.Id)).EnsureSuccessStatusCode();

        var saved = factory.Clock.Now;
        try
        {
            // 23:59 Tashkent time on the same day: still active.
            var today = Scenario.Today(factory);
            factory.Clock.Now = new DateTimeOffset(today.ToDateTime(new TimeOnly(23, 59)), TimeSpan.FromHours(5));
            Assert.Equal(MembershipEffectiveStatus.Active,
                (await client.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json))!.Single().EffectiveStatus);

            // 00:01 next day in Tashkent (still the previous day in UTC): expired.
            factory.Clock.Now = new DateTimeOffset(today.AddDays(1).ToDateTime(new TimeOnly(0, 1)), TimeSpan.FromHours(5));
            Assert.Equal(MembershipEffectiveStatus.Expired,
                (await client.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json))!.Single().EffectiveStatus);
        }
        finally { factory.Clock.Now = saved; }
    }

    [Fact]
    public async Task Freeze_and_cancel_change_effective_status()
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin);
        var (client, _) = await _s.RegisterClientAsync();
        var res = await _s.AssignAsync(admin, await _s.ClientIdAsync(client), plan.Id);
        var m = (await res.Content.ReadFromJsonAsync<MembershipDto>(Json))!;

        var frozen = await admin.PutAsJsonAsync($"/api/admin/memberships/{m.Id}", new { status = "Frozen", m.StartDate, m.EndDate }, Json);
        Assert.Equal(MembershipEffectiveStatus.Frozen, (await frozen.Content.ReadFromJsonAsync<MembershipDto>(Json))!.EffectiveStatus);
        var cancelled = await admin.PutAsJsonAsync($"/api/admin/memberships/{m.Id}", new { status = "Cancelled", m.StartDate, m.EndDate }, Json);
        Assert.Equal(MembershipEffectiveStatus.Cancelled, (await cancelled.Content.ReadFromJsonAsync<MembershipDto>(Json))!.EffectiveStatus);

        var bad = await admin.PutAsJsonAsync($"/api/admin/memberships/{m.Id}", new { status = "Active", startDate = m.EndDate, endDate = m.StartDate }, Json);
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
    }

    [Fact]
    public async Task Inactive_plan_cannot_be_assigned_and_plan_validation_works()
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin);
        (await admin.PutAsJsonAsync($"/api/admin/membership-plans/{plan.Id}", new
        {
            plan.Name, type = "Unlimited", plan.DurationDays, plan.Price, isActive = false,
        }, Json)).EnsureSuccessStatusCode();
        var (client, _) = await _s.RegisterClientAsync();
        var res = await _s.AssignAsync(admin, await _s.ClientIdAsync(client), plan.Id);
        Assert.Equal(HttpStatusCode.Conflict, res.StatusCode);
        Assert.Equal("plan_inactive", await Scenario.ErrorCodeAsync(res));

        var invalid = await admin.PostAsJsonAsync("/api/admin/membership-plans",
            new { name = "Bad", type = "Unlimited", durationDays = 0, visitLimit = 5, price = -1 }, Json);
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
    }

    [Fact]
    public async Task Client_sees_only_active_plans()
    {
        var admin = await factory.AdminAsync();
        var active = await _s.CreatePlanAsync(admin, days: 90);
        var hidden = await _s.CreatePlanAsync(admin);
        (await admin.PutAsJsonAsync($"/api/admin/membership-plans/{hidden.Id}", new
        {
            hidden.Name, type = "Unlimited", hidden.DurationDays, hidden.Price, isActive = false,
        }, Json)).EnsureSuccessStatusCode();
        var (client, _) = await _s.RegisterClientAsync();

        var plans = (await client.GetFromJsonAsync<List<MembershipPlanDto>>("/api/me/plans", Json))!;
        Assert.Contains(plans, p => p.Id == active.Id && p.Price == active.Price && p.DurationDays == 90);
        Assert.DoesNotContain(plans, p => p.Id == hidden.Id);
        Assert.All(plans, p => Assert.True(p.IsActive));
    }

    [Fact]
    public async Task Visits_are_linked_to_membership_and_limit_is_enforced()
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin, days: 30, visitLimit: 2);
        var (client, _) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);

        var none = await admin.PostAsJsonAsync("/api/admin/visits", new { clientId }, Json);
        Assert.Equal("no_active_membership", await Scenario.ErrorCodeAsync(none));

        (await _s.AssignAsync(admin, clientId, plan.Id)).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Created, (await admin.PostAsJsonAsync("/api/admin/visits", new { clientId }, Json)).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await admin.PostAsJsonAsync("/api/admin/visits", new { clientId }, Json)).StatusCode);
        var third = await admin.PostAsJsonAsync("/api/admin/visits", new { clientId }, Json);
        Assert.Equal(HttpStatusCode.Conflict, third.StatusCode);

        var m = (await client.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json))!.Single();
        Assert.Equal(2, m.VisitsUsed);
        Assert.Equal(MembershipEffectiveStatus.Exhausted, m.EffectiveStatus);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(2, dash!.Visits.Total);
    }

    [Fact]
    public async Task Admin_client_search_and_dashboard_use_real_data()
    {
        var admin = await factory.AdminAsync();
        var phone = ApiFactory.NewPhone();
        var create = await admin.PostAsJsonAsync("/api/admin/clients",
            new { phone, password = Scenario.Password, firstName = "Searchable", lastName = "Person" + phone[^4..] }, Json);
        Assert.Equal(HttpStatusCode.Created, create.StatusCode);

        var byName = await admin.GetFromJsonAsync<PagedResult<ClientAdminDto>>($"/api/admin/clients?search=Person{phone[^4..]}", Json);
        Assert.Contains(byName!.Items, c => c.Phone == phone);
        var byPhone = await admin.GetFromJsonAsync<PagedResult<ClientAdminDto>>($"/api/admin/clients?search={phone[^7..]}", Json);
        Assert.Contains(byPhone!.Items, c => c.Phone == phone);

        var paged = await admin.GetFromJsonAsync<PagedResult<ClientAdminDto>>("/api/admin/clients?page=1&pageSize=1", Json);
        Assert.Single(paged!.Items);
        Assert.Equal(HttpStatusCode.BadRequest, (await admin.GetAsync("/api/admin/clients?pageSize=1000")).StatusCode);

        var dash = await admin.GetFromJsonAsync<FitnessFormulasi.Api.Features.Admin.AdminDashboardDto>("/api/admin/dashboard", Json);
        Assert.True(dash!.TotalClients >= 1);
        var report = await admin.GetAsync("/api/admin/reports/summary");
        Assert.Equal(HttpStatusCode.OK, report.StatusCode);
    }
}
