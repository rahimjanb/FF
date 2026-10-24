using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

[Collection(ApiCollection.Name)]
public class TrainerRequestTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    [Fact]
    public async Task Client_requests_trainer_and_duplicate_pending_request_is_rejected()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var (client, _) = await _s.RegisterClientAsync();
        var req = await _s.RequestTrainerAsync(client, t.Id);
        Assert.Equal(TrainerRequestStatus.Pending, req.Status);

        var dup = await client.PostAsJsonAsync("/api/me/trainer-requests", new { trainerId = t.Id }, Json);
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);
        Assert.Equal("duplicate_request", await Scenario.ErrorCodeAsync(dup));

        // Concurrent duplicates are stopped by the partial unique index.
        var (client2, _) = await _s.RegisterClientAsync();
        var burst = await Task.WhenAll(Enumerable.Range(0, 5).Select(_ =>
            client2.PostAsJsonAsync("/api/me/trainer-requests", new { trainerId = t.Id }, Json)));
        Assert.Equal(1, burst.Count(r => r.StatusCode == HttpStatusCode.Created));
        Assert.All(burst.Where(r => r.StatusCode != HttpStatusCode.Created), r => Assert.Equal(HttpStatusCode.Conflict, r.StatusCode));

        var inbox = await trainer.GetFromJsonAsync<PagedResult<TrainerRequestDto>>("/api/trainer/requests?status=Pending", Json);
        Assert.Equal(2, inbox!.TotalCount);
    }

    [Fact]
    public async Task Cancelled_request_allows_a_new_one()
    {
        var (_, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var (client, _) = await _s.RegisterClientAsync();
        var req = await _s.RequestTrainerAsync(client, t.Id);
        (await client.PostAsync($"/api/me/trainer-requests/{req.Id}/cancel", null)).EnsureSuccessStatusCode();
        await _s.RequestTrainerAsync(client, t.Id);
    }

    [Fact]
    public async Task Trainer_accepts_request_assigning_client_and_closing_other_requests()
    {
        var admin = await factory.AdminAsync();
        var (trainerA, a) = await _s.CreateTrainerAsync(admin);
        var (trainerB, b) = await _s.CreateTrainerAsync(admin);
        var (client, _) = await _s.RegisterClientAsync();
        var toA = await _s.RequestTrainerAsync(client, a.Id);
        var toB = await _s.RequestTrainerAsync(client, b.Id);

        // Trainer B cannot touch A's request.
        Assert.Equal(HttpStatusCode.NotFound, (await trainerB.PostAsJsonAsync($"/api/trainer/requests/{toA.Id}/accept", new { }, Json)).StatusCode);

        var accepted = await trainerA.PostAsJsonAsync($"/api/trainer/requests/{toA.Id}/accept", new { comment = "Welcome" }, Json);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        Assert.Equal(TrainerRequestStatus.Accepted, (await accepted.Content.ReadFromJsonAsync<TrainerRequestDto>(Json))!.Status);

        var mine = await client.GetFromJsonAsync<List<TrainerRequestDto>>("/api/me/trainer-requests", Json);
        Assert.Equal(TrainerRequestStatus.Cancelled, mine!.Single(r => r.Id == toB.Id).Status);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(a.Id, dash!.Trainer!.Id);

        var clients = await trainerA.GetFromJsonAsync<PagedResult<TrainerClientDto>>("/api/trainer/clients", Json);
        Assert.Single(clients!.Items);

        var again = await trainerA.PostAsJsonAsync($"/api/trainer/requests/{toA.Id}/reject", new { }, Json);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal("request_not_pending", await Scenario.ErrorCodeAsync(again));

        var already = await client.PostAsJsonAsync("/api/me/trainer-requests", new { trainerId = a.Id }, Json);
        Assert.Equal("already_assigned", await Scenario.ErrorCodeAsync(already));
    }

    [Fact]
    public async Task Trainer_rejects_request_and_client_is_notified()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var (client, _) = await _s.RegisterClientAsync();
        var req = await _s.RequestTrainerAsync(client, t.Id);

        var res = await trainer.PostAsJsonAsync($"/api/trainer/requests/{req.Id}/reject", new { comment = "Fully booked" }, Json);
        var dto = (await res.Content.ReadFromJsonAsync<TrainerRequestDto>(Json))!;
        Assert.Equal(TrainerRequestStatus.Rejected, dto.Status);
        Assert.Equal("Fully booked", dto.ResponseComment);

        var notifications = await client.GetFromJsonAsync<PagedResult<NotificationDto>>("/api/notifications", Json);
        Assert.Contains(notifications!.Items, n => n.Type == NotificationType.TrainerRequestRejected && n.RelatedEntityId == req.Id);
        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Null(dash!.Trainer);
    }

    [Fact]
    public async Task Admin_can_process_requests_and_trainer_not_accepting_is_refused()
    {
        var admin = await factory.AdminAsync();
        var (_, closed) = await _s.CreateTrainerAsync(admin, accepting: false);
        var (_, open) = await _s.CreateTrainerAsync(admin);
        var (client, _) = await _s.RegisterClientAsync();

        var refused = await client.PostAsJsonAsync("/api/me/trainer-requests", new { trainerId = closed.Id }, Json);
        Assert.Equal("trainer_not_accepting", await Scenario.ErrorCodeAsync(refused));

        var req = await _s.RequestTrainerAsync(client, open.Id);
        var res = await admin.PostAsJsonAsync($"/api/admin/trainer-requests/{req.Id}/accept", new { }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
    }

    [Fact]
    public async Task Trainer_schedules_session_visible_to_client_and_overlap_is_rejected()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var (client, _) = await _s.RegisterClientAsync();
        var req = await _s.RequestTrainerAsync(client, t.Id);
        (await trainer.PostAsJsonAsync($"/api/trainer/requests/{req.Id}/accept", new { }, Json)).EnsureSuccessStatusCode();
        var clientId = await _s.ClientIdAsync(client);
        var startsAt = factory.Clock.Now.AddDays(1);

        var created = await trainer.PostAsJsonAsync("/api/trainer/sessions", new { clientId, startsAt, durationMinutes = 60 }, Json);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var overlap = await trainer.PostAsJsonAsync("/api/trainer/sessions", new { clientId, startsAt = startsAt.AddMinutes(30), durationMinutes = 60 }, Json);
        Assert.Equal("session_overlap", await Scenario.ErrorCodeAsync(overlap));
        var past = await trainer.PostAsJsonAsync("/api/trainer/sessions", new { clientId, startsAt = factory.Clock.Now.AddHours(-1), durationMinutes = 60 }, Json);
        Assert.Equal("start_in_past", await Scenario.ErrorCodeAsync(past));

        var dash = await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json);
        Assert.Equal(startsAt, dash!.NextSession!.StartsAt);
        var sessions = await trainer.GetFromJsonAsync<List<TrainingSessionDto>>("/api/trainer/sessions", Json);
        Assert.Single(sessions!);

        var session = (await created.Content.ReadFromJsonAsync<TrainingSessionDto>(Json))!;
        var cancel = await trainer.PostAsync($"/api/trainer/sessions/{session.Id}/cancel", null);
        Assert.Equal(TrainingSessionStatus.Cancelled, (await cancel.Content.ReadFromJsonAsync<TrainingSessionDto>(Json))!.Status);
    }
}
