using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

[Collection(ApiCollection.Name)]
public class AccessControlTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    [Theory]
    [InlineData("/api/admin/dashboard")]
    [InlineData("/api/admin/clients")]
    [InlineData("/api/me/dashboard")]
    [InlineData("/api/me/plans")]
    [InlineData("/api/trainer/clients")]
    [InlineData("/api/trainers")]
    public async Task Anonymous_requests_are_rejected(string url) =>
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync(url)).StatusCode);

    [Theory]
    [InlineData("/api/admin/dashboard")]
    [InlineData("/api/admin/clients")]
    [InlineData("/api/admin/memberships")]
    [InlineData("/api/trainer/clients")]
    [InlineData("/api/trainer/requests")]
    public async Task Client_cannot_reach_admin_or_trainer_endpoints(string url)
    {
        var (client, _) = await _s.RegisterClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(url)).StatusCode);
    }

    [Theory]
    [InlineData("/api/admin/clients")]
    [InlineData("/api/me/dashboard")]
    [InlineData("/api/me/plans")]
    public async Task Trainer_cannot_reach_admin_or_client_endpoints(string url)
    {
        var (trainer, _) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        Assert.Equal(HttpStatusCode.Forbidden, (await trainer.GetAsync(url)).StatusCode);
    }

    [Fact]
    public async Task Client_cannot_assign_membership_to_self()
    {
        var (client, _) = await _s.RegisterClientAsync();
        var res = await client.PostAsJsonAsync("/api/admin/memberships", new { clientId = await _s.ClientIdAsync(client), planId = Guid.NewGuid() }, Json);
        Assert.Equal(HttpStatusCode.Forbidden, res.StatusCode);
    }

    [Fact]
    public async Task Trainer_cannot_see_or_schedule_other_trainers_clients()
    {
        var admin = await factory.AdminAsync();
        var (trainerA, a) = await _s.CreateTrainerAsync(admin);
        var (trainerB, _) = await _s.CreateTrainerAsync(admin);
        var (client, _) = await _s.RegisterClientAsync();
        var req = await _s.RequestTrainerAsync(client, a.Id);
        (await trainerA.PostAsJsonAsync($"/api/trainer/requests/{req.Id}/accept", new { }, Json)).EnsureSuccessStatusCode();
        var clientId = await _s.ClientIdAsync(client);

        Assert.Equal(HttpStatusCode.OK, (await trainerA.GetAsync($"/api/trainer/clients/{clientId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await trainerB.GetAsync($"/api/trainer/clients/{clientId}")).StatusCode);
        var listB = await trainerB.GetFromJsonAsync<FitnessFormulasi.Api.Common.PagedResult<TrainerClientDto>>("/api/trainer/clients", Json);
        Assert.DoesNotContain(listB!.Items, c => c.Id == clientId);

        var schedule = await trainerB.PostAsJsonAsync("/api/trainer/sessions",
            new { clientId, startsAt = factory.Clock.Now.AddDays(1), durationMinutes = 60 }, Json);
        Assert.Equal(HttpStatusCode.NotFound, schedule.StatusCode);
    }

    [Fact]
    public async Task Client_cannot_cancel_another_clients_request()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var (owner, _) = await _s.RegisterClientAsync();
        var (other, _) = await _s.RegisterClientAsync();
        var req = await _s.RequestTrainerAsync(owner, t.Id);

        var res = await other.PostAsync($"/api/me/trainer-requests/{req.Id}/cancel", null);
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
        var mine = await other.GetFromJsonAsync<List<TrainerRequestDto>>("/api/me/trainer-requests", Json);
        Assert.Empty(mine!);
    }

    [Fact]
    public async Task Client_does_not_see_staff_notes_or_trainer_contacts()
    {
        var (client, _) = await _s.RegisterClientAsync();
        var trainers = await client.GetStringAsync("/api/trainers");
        Assert.DoesNotContain("phone", trainers, StringComparison.OrdinalIgnoreCase);
        var profile = await client.GetStringAsync("/api/me/profile");
        Assert.DoesNotContain("notes", profile, StringComparison.OrdinalIgnoreCase);
    }
}
