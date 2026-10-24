using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace FitnessFormulasi.Api.Tests;

[Collection(ApiCollection.Name)]
public class TrainingSessionTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    /// <summary>Trainer with one assigned client (request accepted through the API).</summary>
    private async Task<(HttpClient Trainer, Guid TrainerId, HttpClient Client, Guid ClientId)> PairAsync()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var (client, _) = await _s.RegisterClientAsync();
        var req = await _s.RequestTrainerAsync(client, t.Id);
        (await trainer.PostAsJsonAsync($"/api/trainer/requests/{req.Id}/accept", new { }, Json)).EnsureSuccessStatusCode();
        return (trainer, t.Id, client, await _s.ClientIdAsync(client));
    }

    private static async Task<TrainingSessionDto> ScheduleAsync(HttpClient trainer, Guid clientId, DateTimeOffset startsAt, int minutes = 60)
    {
        var res = await trainer.PostAsJsonAsync("/api/trainer/sessions", new { clientId, startsAt, durationMinutes = minutes }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<TrainingSessionDto>(Json))!;
    }

    private static Task<PagedResult<TrainingSessionDto>?> ClientSessionsAsync(HttpClient client, string scope) =>
        client.GetFromJsonAsync<PagedResult<TrainingSessionDto>>($"/api/me/training-sessions?scope={scope}", Json);

    [Fact]
    public async Task Client_with_no_sessions_gets_empty_lists()
    {
        var (client, _) = await _s.RegisterClientAsync();
        Assert.Empty((await ClientSessionsAsync(client, "Upcoming"))!.Items);
        Assert.Empty((await ClientSessionsAsync(client, "History"))!.Items);
        var trainerEmpty = await PairAsync();
        Assert.Empty((await trainerEmpty.Trainer.GetFromJsonAsync<List<TrainingSessionDto>>("/api/trainer/sessions", Json))!);
    }

    [Fact]
    public async Task Upcoming_and_history_are_split_by_time_and_status()
    {
        var (trainer, _, client, clientId) = await PairAsync();
        var now = factory.Clock.Now;
        var soon = await ScheduleAsync(trainer, clientId, now.AddHours(2));
        var later = await ScheduleAsync(trainer, clientId, now.AddDays(3));
        var cancelled = await ScheduleAsync(trainer, clientId, now.AddDays(5));
        (await trainer.PostAsync($"/api/trainer/sessions/{cancelled.Id}/cancel", null)).EnsureSuccessStatusCode();
        var finished = await ScheduleAsync(trainer, clientId, now.AddHours(4), 60);

        var saved = factory.Clock.Now;
        try
        {
            // Six hours later: "soon" and "finished" have ended without being marked.
            factory.Clock.Now = saved.AddHours(6);
            (await trainer.PostAsync($"/api/trainer/sessions/{finished.Id}/complete", null)).EnsureSuccessStatusCode();

            var upcoming = (await ClientSessionsAsync(client, "Upcoming"))!.Items;
            Assert.Equal([later.Id], upcoming.Select(s => s.Id));

            var history = (await ClientSessionsAsync(client, "History"))!.Items;
            // Most recent first: cancelled (day 5), finished (4h), soon (2h).
            Assert.Equal([cancelled.Id, finished.Id, soon.Id], history.Select(s => s.Id));
            Assert.Equal(TrainingSessionStatus.Completed, history.Single(s => s.Id == finished.Id).Status);
            Assert.Equal(TrainingSessionStatus.Scheduled, history.Single(s => s.Id == soon.Id).Status); // ended, not marked
        }
        finally { factory.Clock.Now = saved; }
    }

    [Fact]
    public async Task Session_in_progress_is_still_upcoming()
    {
        var (trainer, _, client, clientId) = await PairAsync();
        var s = await ScheduleAsync(trainer, clientId, factory.Clock.Now.AddHours(1), 90);
        var saved = factory.Clock.Now;
        try
        {
            factory.Clock.Now = saved.AddHours(2); // started 1h ago, ends in 30 min
            Assert.Contains((await ClientSessionsAsync(client, "Upcoming"))!.Items, x => x.Id == s.Id);
        }
        finally { factory.Clock.Now = saved; }
    }

    [Fact]
    public async Task Client_sees_only_own_sessions_and_trainer_only_own_schedule()
    {
        var (trainerA, _, clientA, clientAId) = await PairAsync();
        var (trainerB, _, clientB, clientBId) = await PairAsync();
        var a = await ScheduleAsync(trainerA, clientAId, factory.Clock.Now.AddDays(1));
        var b = await ScheduleAsync(trainerB, clientBId, factory.Clock.Now.AddDays(1));

        Assert.Equal([a.Id], (await ClientSessionsAsync(clientA, "Upcoming"))!.Items.Select(s => s.Id));
        Assert.Equal([b.Id], (await ClientSessionsAsync(clientB, "Upcoming"))!.Items.Select(s => s.Id));
        Assert.Equal([a.Id], (await trainerA.GetFromJsonAsync<List<TrainingSessionDto>>("/api/trainer/sessions", Json))!.Select(s => s.Id));

        // Trainer B cannot change trainer A's session; the session is not revealed.
        Assert.Equal(HttpStatusCode.NotFound, (await trainerB.PostAsync($"/api/trainer/sessions/{a.Id}/cancel", null)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await trainerB.PostAsync($"/api/trainer/sessions/{a.Id}/complete", null)).StatusCode);
        // Clients cannot use trainer endpoints at all.
        Assert.Equal(HttpStatusCode.Forbidden, (await clientA.PostAsync($"/api/trainer/sessions/{a.Id}/cancel", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await clientA.GetAsync("/api/trainer/sessions")).StatusCode);
    }

    [Fact]
    public async Task Status_changes_follow_rules()
    {
        var (trainer, _, client, clientId) = await PairAsync();
        var s = await ScheduleAsync(trainer, clientId, factory.Clock.Now.AddHours(1));

        var early = await trainer.PostAsync($"/api/trainer/sessions/{s.Id}/complete", null);
        Assert.Equal("session_not_started", await Scenario.ErrorCodeAsync(early));

        var saved = factory.Clock.Now;
        try
        {
            factory.Clock.Now = saved.AddHours(2);
            var done = await trainer.PostAsync($"/api/trainer/sessions/{s.Id}/complete", null);
            Assert.Equal(TrainingSessionStatus.Completed, (await done.Content.ReadFromJsonAsync<TrainingSessionDto>(Json))!.Status);
            // No approved rule links a completed session to visits, so nothing is recorded or deducted.
            using (var scope = factory.Services.CreateScope())
                Assert.False(await scope.ServiceProvider.GetRequiredService<AppDbContext>().Visits.AnyAsync(v => v.ClientProfileId == clientId));
            var again = await trainer.PostAsync($"/api/trainer/sessions/{s.Id}/cancel", null);
            Assert.Equal("session_not_scheduled", await Scenario.ErrorCodeAsync(again));
        }
        finally { factory.Clock.Now = saved; }

        var cancelled = await ScheduleAsync(trainer, clientId, factory.Clock.Now.AddDays(2));
        (await trainer.PostAsync($"/api/trainer/sessions/{cancelled.Id}/cancel", null)).EnsureSuccessStatusCode();
        var notifications = await client.GetFromJsonAsync<PagedResult<NotificationDto>>("/api/notifications", Json);
        Assert.Contains(notifications!.Items, n => n.Type == NotificationType.TrainingSessionCancelled && n.RelatedEntityId == cancelled.Id);
        Assert.Contains(notifications.Items, n => n.Type == NotificationType.TrainingSessionScheduled && n.RelatedEntityId == cancelled.Id);
    }

    [Fact]
    public async Task Trainer_schedule_includes_last_week_so_unmarked_sessions_can_be_closed()
    {
        var (trainer, _, _, clientId) = await PairAsync();
        var s = await ScheduleAsync(trainer, clientId, factory.Clock.Now.AddHours(1));
        var saved = factory.Clock.Now;
        try
        {
            factory.Clock.Now = saved.AddDays(3);
            var list = await trainer.GetFromJsonAsync<List<TrainingSessionDto>>("/api/trainer/sessions", Json);
            Assert.Contains(list!, x => x.Id == s.Id);
            Assert.Equal(HttpStatusCode.OK, (await trainer.PostAsync($"/api/trainer/sessions/{s.Id}/complete", null)).StatusCode);

            factory.Clock.Now = saved.AddDays(10);
            Assert.DoesNotContain((await trainer.GetFromJsonAsync<List<TrainingSessionDto>>("/api/trainer/sessions", Json))!, x => x.Id == s.Id);
        }
        finally { factory.Clock.Now = saved; }

        var bad = await trainer.GetAsync("/api/trainer/sessions?from=2026-05-10&to=2026-05-01");
        Assert.Equal("invalid_range", await Scenario.ErrorCodeAsync(bad));
        var tooLong = await trainer.GetAsync("/api/trainer/sessions?from=2026-01-01&to=2026-12-31");
        Assert.Equal("invalid_range", await Scenario.ErrorCodeAsync(tooLong));
    }

    [Fact]
    public async Task Reassigned_client_cannot_be_scheduled_by_previous_trainer()
    {
        var (trainerA, _, client, clientId) = await PairAsync();
        var (_, b) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var profile = await client.GetFromJsonAsync<ClientProfileDto>("/api/me/profile", Json);
        var admin = await factory.AdminAsync();
        (await admin.PutAsJsonAsync($"/api/admin/clients/{clientId}", new
        {
            phone = profile!.Phone, firstName = profile.FirstName, lastName = profile.LastName, status = "Active", assignedTrainerId = b.Id,
        }, Json)).EnsureSuccessStatusCode();

        var res = await trainerA.PostAsJsonAsync("/api/trainer/sessions",
            new { clientId, startsAt = factory.Clock.Now.AddDays(1), durationMinutes = 60 }, Json);
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await trainerA.GetAsync($"/api/trainer/clients/{clientId}")).StatusCode);
    }
}
