using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

/// <summary>Training without a trainer, and the trainer's Telegram / Instagram shown after a request.</summary>
[Collection(ApiCollection.Name)]
public class TrainerChoiceTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private async Task<(HttpClient Http, TrainerAdminDto Trainer)> TrainerWithContactsAsync(HttpClient admin, string? telegram, string? instagram)
    {
        var (http, trainer) = await _s.CreateTrainerAsync(admin);
        var res = await admin.PutAsJsonAsync($"/api/admin/trainers/{trainer.Id}", new
        {
            phone = trainer.Phone, trainer.FirstName, trainer.LastName, telegram, instagram,
            isAcceptingClients = true, isActive = true, status = "Active",
        }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        return (http, (await res.Content.ReadFromJsonAsync<TrainerAdminDto>(Json))!);
    }

    [Fact]
    public async Task Trainer_contacts_are_normalized_hidden_from_the_directory_and_returned_with_the_request()
    {
        var admin = await factory.AdminAsync();
        var (trainerHttp, trainer) = await TrainerWithContactsAsync(admin, "@Coach_Aziz", "https://www.instagram.com/coach.aziz/?hl=ru");
        Assert.Equal(("Coach_Aziz", "coach.aziz"), (trainer.Telegram, trainer.Instagram));

        var (client, _) = await _s.RegisterClientAsync();
        var listed = (await client.GetFromJsonAsync<List<TrainerPublicDto>>("/api/trainers", Json))!.Single(t => t.Id == trainer.Id);
        Assert.Null(listed.Telegram);
        Assert.Null(listed.Instagram);

        var request = await _s.RequestTrainerAsync(client, trainer.Id);
        Assert.Equal(("Coach_Aziz", "coach.aziz"), (request.TrainerTelegram, request.TrainerInstagram));
        var mine = (await client.GetFromJsonAsync<List<TrainerRequestDto>>("/api/me/trainer-requests", Json))!.Single();
        Assert.Equal("Coach_Aziz", mine.TrainerTelegram);

        // Once assigned, the client's own trainer carries the contacts in the profile and on the dashboard.
        (await trainerHttp.PostAsJsonAsync($"/api/trainer/requests/{request.Id}/accept", new { }, Json)).EnsureSuccessStatusCode();
        var profile = (await client.GetFromJsonAsync<ClientProfileDto>("/api/me/profile", Json))!;
        Assert.Equal("coach.aziz", profile.AssignedTrainer!.Instagram);
        var dash = (await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json))!;
        Assert.Equal("Coach_Aziz", dash.Trainer!.Telegram);
    }

    [Theory]
    [InlineData("ab", null, "invalid_telegram")]
    [InlineData("https://t.me/имя", null, "invalid_telegram")]
    [InlineData(null, "bad name", "invalid_instagram")]
    [InlineData(null, "a..b", "invalid_instagram")]
    public async Task Invalid_contacts_are_rejected(string? telegram, string? instagram, string code)
    {
        var admin = await factory.AdminAsync();
        var (_, trainer) = await _s.CreateTrainerAsync(admin);
        var res = await admin.PutAsJsonAsync($"/api/admin/trainers/{trainer.Id}", new
        {
            phone = trainer.Phone, trainer.FirstName, trainer.LastName, telegram, instagram,
            isAcceptingClients = true, isActive = true, status = "Active",
        }, Json);
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        Assert.Equal(code, await Scenario.ErrorCodeAsync(res));
    }

    [Fact]
    public async Task Client_chooses_to_train_without_a_trainer_and_can_still_pick_one_later()
    {
        var admin = await factory.AdminAsync();
        var (trainerHttp, trainer) = await _s.CreateTrainerAsync(admin);
        var (client, _) = await _s.RegisterClientAsync();
        var pending = await _s.RequestTrainerAsync(client, trainer.Id);

        var res = await client.PostAsync("/api/me/without-trainer", null);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.True((await res.Content.ReadFromJsonAsync<ClientProfileDto>(Json))!.WithoutTrainer);
        var requests = (await client.GetFromJsonAsync<List<TrainerRequestDto>>("/api/me/trainer-requests", Json))!;
        Assert.Equal(TrainerRequestStatus.Cancelled, requests.Single(r => r.Id == pending.Id).Status);
        var dash = (await client.GetFromJsonAsync<ClientDashboardDto>("/api/me/dashboard", Json))!;
        Assert.True(dash.WithoutTrainer);
        Assert.Null(dash.PendingTrainerRequest);

        // A trainer accepted later replaces the choice.
        var again = await _s.RequestTrainerAsync(client, trainer.Id);
        (await trainerHttp.PostAsJsonAsync($"/api/trainer/requests/{again.Id}/accept", new { }, Json)).EnsureSuccessStatusCode();
        var profile = (await client.GetFromJsonAsync<ClientProfileDto>("/api/me/profile", Json))!;
        Assert.False(profile.WithoutTrainer);
        Assert.Equal(trainer.Id, profile.AssignedTrainer!.Id);

        var withTrainer = await client.PostAsync("/api/me/without-trainer", null);
        Assert.Equal(HttpStatusCode.Conflict, withTrainer.StatusCode);
        Assert.Equal("trainer_assigned", await Scenario.ErrorCodeAsync(withTrainer));
    }
}
