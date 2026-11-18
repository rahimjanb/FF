using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

/// <summary>Freezing, renewal / plan change requests and QR check-in at the club desk.</summary>
[Collection(ApiCollection.Name)]
public class DeskTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private async Task<(HttpClient Admin, HttpClient Client, Guid ClientId, MembershipDto Membership)> ClientWithMembershipAsync(
        int days = 30, int? visitLimit = null, DateOnly? start = null)
    {
        var admin = await factory.AdminAsync();
        var plan = await _s.CreatePlanAsync(admin, days, visitLimit);
        var (client, _) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);
        var res = await _s.AssignAsync(admin, clientId, plan.Id, start);
        res.EnsureSuccessStatusCode();
        return (admin, client, clientId, (await res.Content.ReadFromJsonAsync<MembershipDto>(Json))!);
    }

    private static async Task<CheckInResultDto> ScanAsync(HttpClient admin, string code)
    {
        var res = await admin.PostAsJsonAsync("/api/admin/check-in", new { code }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<CheckInResultDto>(Json))!;
    }

    private static async Task<string> PassAsync(HttpClient client) =>
        (await client.GetFromJsonAsync<PassDto>("/api/me/pass", Json))!.Code;

    [Fact]
    public async Task Freeze_moves_the_end_date_and_the_next_membership_and_unfreeze_takes_unused_days_back()
    {
        var (admin, client, clientId, m) = await ClientWithMembershipAsync(days: 180);
        var today = Scenario.Today(factory);
        var nextPlan = await _s.CreatePlanAsync(admin, 10);
        var next = (await (await _s.AssignAsync(admin, clientId, nextPlan.Id, m.EndDate.AddDays(1))).Content
            .ReadFromJsonAsync<MembershipDto>(Json))!;

        var res = await admin.PostAsJsonAsync($"/api/admin/memberships/{m.Id}/freeze",
            new { startDate = today, endDate = today.AddDays(9) }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var frozen = (await res.Content.ReadFromJsonAsync<MembershipDto>(Json))!;
        Assert.Equal(MembershipEffectiveStatus.Frozen, frozen.EffectiveStatus);
        Assert.Equal(m.EndDate.AddDays(10), frozen.EndDate);
        Assert.Equal(today, frozen.FreezeStartDate);
        Assert.Equal(today.AddDays(9), frozen.FreezeEndDate);
        var movedNext = await admin.GetFromJsonAsync<MembershipDto>($"/api/admin/memberships/{next.Id}", Json);
        Assert.Equal(next.StartDate.AddDays(10), movedNext!.StartDate);

        // A second freeze while one is current is refused; the client sees the freeze in the app.
        var again = await admin.PostAsJsonAsync($"/api/admin/memberships/{m.Id}/freeze",
            new { startDate = today.AddDays(12), endDate = today.AddDays(13) }, Json);
        Assert.Equal("freeze_exists", await Scenario.ErrorCodeAsync(again));
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(MembershipEffectiveStatus.Frozen, dash!.CurrentMembership!.EffectiveStatus);
        var frozenList = await admin.GetFromJsonAsync<PagedResult<MembershipDto>>($"/api/admin/memberships?status=Frozen&clientId={clientId}", Json);
        Assert.Single(frozenList!.Items);
        var activeList = await admin.GetFromJsonAsync<PagedResult<MembershipDto>>($"/api/admin/memberships?status=Active&clientId={clientId}", Json);
        Assert.Empty(activeList!.Items);

        // Ended on the day it started: all ten days come back.
        var unfrozen = (await (await admin.PostAsync($"/api/admin/memberships/{m.Id}/unfreeze", null)).Content
            .ReadFromJsonAsync<MembershipDto>(Json))!;
        Assert.Equal(MembershipEffectiveStatus.Active, unfrozen.EffectiveStatus);
        Assert.Equal(m.EndDate, unfrozen.EndDate);
        Assert.Null(unfrozen.FreezeStartDate);
        movedNext = await admin.GetFromJsonAsync<MembershipDto>($"/api/admin/memberships/{next.Id}", Json);
        Assert.Equal(next.StartDate, movedNext!.StartDate);
    }

    [Fact]
    public async Task Freeze_is_validated()
    {
        var (admin, _, _, m) = await ClientWithMembershipAsync(days: 180);
        var today = Scenario.Today(factory);
        async Task<string?> Freeze(DateOnly from, DateOnly to) => await Scenario.ErrorCodeAsync(
            await admin.PostAsJsonAsync($"/api/admin/memberships/{m.Id}/freeze", new { startDate = from, endDate = to }, Json));

        Assert.Equal("freeze_in_past", await Freeze(today.AddDays(-1), today.AddDays(2)));
        Assert.Equal("invalid_dates", await Freeze(today.AddDays(3), today.AddDays(2)));
        Assert.Equal("freeze_outside_membership", await Freeze(m.EndDate.AddDays(1), m.EndDate.AddDays(3)));
        Assert.Equal("not_frozen", await Scenario.ErrorCodeAsync(await admin.PostAsync($"/api/admin/memberships/{m.Id}/unfreeze", null)));
    }

    [Fact]
    public async Task Renewal_request_is_completed_by_staff_after_payment_and_starts_after_the_current_membership()
    {
        var (admin, client, clientId, m) = await ClientWithMembershipAsync();
        var res = await client.PostAsJsonAsync("/api/me/membership-requests", new { planId = m.PlanId, kind = "Renew" }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        var request = (await res.Content.ReadFromJsonAsync<MembershipRequestDto>(Json))!;
        Assert.Equal(MembershipRequestStatus.Pending, request.Status);

        var duplicate = await client.PostAsJsonAsync("/api/me/membership-requests", new { planId = m.PlanId, kind = "Renew" }, Json);
        Assert.Equal("membership_request_pending", await Scenario.ErrorCodeAsync(duplicate));

        var queue = await admin.GetFromJsonAsync<PagedResult<MembershipRequestAdminDto>>(
            "/api/admin/membership-requests?status=Pending&pageSize=100", Json);
        var item = queue!.Items.Single(i => i.Request.Id == request.Id);
        Assert.Equal(m.EndDate.AddDays(1), item.SuggestedStartDate);
        Assert.Equal(m.Id, item.CurrentMembership!.Id);

        var done = (await (await admin.PostAsJsonAsync($"/api/admin/membership-requests/{request.Id}/complete", new { }, Json))
            .Content.ReadFromJsonAsync<MembershipRequestDto>(Json))!;
        Assert.Equal(MembershipRequestStatus.Completed, done.Status);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(done.MembershipId, dash!.NextMembership!.Id);
        Assert.Equal(m.EndDate.AddDays(1), dash.NextMembership.StartDate);

        var twice = await admin.PostAsJsonAsync($"/api/admin/membership-requests/{request.Id}/complete", new { }, Json);
        Assert.Equal("membership_request_not_pending", await Scenario.ErrorCodeAsync(twice));
    }

    [Fact]
    public async Task Plan_change_can_start_today_closing_the_current_membership_and_a_request_can_be_rejected_or_cancelled()
    {
        var (admin, client, clientId, m) = await ClientWithMembershipAsync(start: Scenario.Today(factory).AddDays(-5));
        var today = Scenario.Today(factory);
        var other = await _s.CreatePlanAsync(admin, 90);

        var request = (await (await client.PostAsJsonAsync("/api/me/membership-requests", new { planId = other.Id, kind = "Change" }, Json))
            .Content.ReadFromJsonAsync<MembershipRequestDto>(Json))!;
        (await admin.PostAsJsonAsync($"/api/admin/membership-requests/{request.Id}/complete", new { closeCurrent = true }, Json))
            .EnsureSuccessStatusCode();

        var mine = (await client.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json))!;
        Assert.Equal(today.AddDays(-1), mine.Single(x => x.Id == m.Id).EndDate);
        var current = (await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json))!.CurrentMembership!;
        Assert.Equal(other.Id, current.PlanId);
        Assert.Equal(today, current.StartDate);

        var second = (await (await client.PostAsJsonAsync("/api/me/membership-requests", new { planId = other.Id, kind = "Renew" }, Json))
            .Content.ReadFromJsonAsync<MembershipRequestDto>(Json))!;
        var rejected = (await (await admin.PostAsJsonAsync($"/api/admin/membership-requests/{second.Id}/reject", new { comment = "Нет оплаты" }, Json))
            .Content.ReadFromJsonAsync<MembershipRequestDto>(Json))!;
        Assert.Equal(MembershipRequestStatus.Rejected, rejected.Status);
        var notes = await client.GetFromJsonAsync<PagedResult<NotificationDto>>("/api/notifications", Json);
        Assert.Contains(notes!.Items, n => n.Type == NotificationType.MembershipRequestRejected);

        var third = (await (await client.PostAsJsonAsync("/api/me/membership-requests", new { planId = other.Id, kind = "Renew" }, Json))
            .Content.ReadFromJsonAsync<MembershipRequestDto>(Json))!;
        var cancelled = (await (await client.PostAsync($"/api/me/membership-requests/{third.Id}/cancel", null))
            .Content.ReadFromJsonAsync<MembershipRequestDto>(Json))!;
        Assert.Equal(MembershipRequestStatus.Cancelled, cancelled.Status);
    }

    [Fact]
    public async Task Valid_pass_records_a_qr_visit_once_and_a_repeated_scan_returns_the_same_visit()
    {
        var (admin, client, clientId, m) = await ClientWithMembershipAsync(visitLimit: 10);
        var pass = await client.GetFromJsonAsync<PassDto>("/api/me/pass", Json);
        Assert.StartsWith("FF1", pass!.Code);
        Assert.Matches("^[A-Z0-9]+$", pass.Code);
        Assert.Equal(pass.Code, await PassAsync(client)); // same code within the 30-second window

        var first = await ScanAsync(admin, pass.Code.ToLowerInvariant() + "\n"); // scanners may change case or add a newline
        Assert.True(first.Allowed);
        Assert.False(first.Repeated);
        Assert.Equal(clientId, first.Client!.Id);
        Assert.Equal(VisitSource.QrScan, first.Visit!.Source);
        Assert.Equal(1, first.Membership!.VisitsUsed);
        Assert.Equal(1, first.VisitsToday);

        var second = await ScanAsync(admin, pass.Code);
        Assert.True(second.Allowed);
        Assert.True(second.Repeated);
        Assert.Equal(first.Visit.Id, second.Visit!.Id);

        // The visit is everywhere: the client's history, the dashboard stats and the pass (for the app's confirmation).
        var visits = await client.GetFromJsonAsync<PagedResult<VisitDto>>("/api/me/visits", Json);
        Assert.Single(visits!.Items);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(1, dash!.Visits.Total);
        Assert.NotNull((await client.GetFromJsonAsync<PassDto>("/api/me/pass", Json))!.LastVisitAt);
        var adminVisits = await admin.GetFromJsonAsync<PagedResult<VisitDto>>($"/api/admin/visits?clientId={clientId}", Json);
        Assert.Equal(VisitSource.QrScan, adminVisits!.Items.Single().Source);

        // Recorded by mistake: undone within 15 minutes.
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"/api/admin/visits/{first.Visit.Id}")).StatusCode);
        visits = await client.GetFromJsonAsync<PagedResult<VisitDto>>("/api/me/visits", Json);
        Assert.Empty(visits!.Items);
    }

    [Fact]
    public async Task Refused_scans_say_why_and_record_nothing()
    {
        var admin = await factory.AdminAsync();
        Assert.Equal(CheckInDenials.InvalidCode, (await ScanAsync(admin, "hello")).Reason);

        // No membership at all.
        var (bare, _) = await _s.RegisterClientAsync();
        var none = await ScanAsync(admin, await PassAsync(bare));
        Assert.False(none.Allowed);
        Assert.Equal(CheckInDenials.NoMembership, none.Reason);
        Assert.NotNull(none.Client);

        // Expired.
        var (_, expiredClient, _, _) = await ClientWithMembershipAsync(days: 5, start: Scenario.Today(factory).AddDays(-10));
        Assert.Equal(CheckInDenials.MembershipExpired, (await ScanAsync(admin, await PassAsync(expiredClient))).Reason);

        // Frozen.
        var (_, frozenClient, _, frozenM) = await ClientWithMembershipAsync(days: 180);
        var today = Scenario.Today(factory);
        (await admin.PostAsJsonAsync($"/api/admin/memberships/{frozenM.Id}/freeze", new { startDate = today, endDate = today.AddDays(3) }, Json))
            .EnsureSuccessStatusCode();
        Assert.Equal(CheckInDenials.MembershipFrozen, (await ScanAsync(admin, await PassAsync(frozenClient))).Reason);

        // Visit limit used up.
        var (_, limitedClient, limitedId, _) = await ClientWithMembershipAsync(visitLimit: 1);
        (await admin.PostAsJsonAsync("/api/admin/visits", new { clientId = limitedId }, Json)).EnsureSuccessStatusCode();
        var exhausted = await ScanAsync(admin, await PassAsync(limitedClient));
        Assert.Equal(CheckInDenials.VisitLimitReached, exhausted.Reason);
        Assert.Equal(1, exhausted.VisitsToday);

        // Forged signature.
        var (_, okClient, _, _) = await ClientWithMembershipAsync();
        var code = await PassAsync(okClient);
        var forged = code[..^1] + (code[^1] == 'A' ? 'B' : 'A');
        Assert.Equal(CheckInDenials.InvalidCode, (await ScanAsync(admin, forged)).Reason);

        // A screenshot is useless a minute later.
        var saved = factory.Clock.Now;
        try
        {
            factory.Clock.Now = saved.AddSeconds(PassTokenService.LifetimeSeconds + 40);
            Assert.Equal(CheckInDenials.ExpiredCode, (await ScanAsync(admin, code)).Reason);
        }
        finally { factory.Clock.Now = saved; }
    }

    [Fact]
    public async Task Only_staff_can_check_in_and_only_clients_get_a_pass()
    {
        var (_, client, _, _) = await ClientWithMembershipAsync();
        var code = await PassAsync(client);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync("/api/admin/check-in", new { code }, Json)).StatusCode);
        var admin = await factory.AdminAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await admin.GetAsync("/api/me/pass")).StatusCode);
    }
}
