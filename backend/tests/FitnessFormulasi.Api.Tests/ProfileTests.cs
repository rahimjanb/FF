using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

/// <summary>Contract 2.1: the client manages their profile and personal data; the trainer edits their own card.</summary>
[Collection(ApiCollection.Name)]
public class ProfileTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    [Fact]
    public async Task Client_updates_allowed_fields_and_cannot_change_protected_ones()
    {
        var (client, auth) = await _s.RegisterClientAsync();
        var (_, trainer) = await _s.CreateTrainerAsync(await factory.AdminAsync());

        // Extra fields (phone, role, trainer, staff notes) are not part of the request model and are ignored.
        var res = await client.PutAsJsonAsync("/api/me/profile", new
        {
            firstName = "  Aziza ", lastName = "Karimova", email = "aziza@example.uz", birthDate = "1995-04-12", gender = "Female",
            phone = "+998900000099", role = "Admin", assignedTrainerId = trainer.Id, notes = "VIP",
        }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var p = (await client.GetFromJsonAsync<ClientProfileDto>("/api/me/profile", Json))!;
        Assert.Equal("Aziza", p.FirstName);
        Assert.Equal("Karimova", p.LastName);
        Assert.Equal("aziza@example.uz", p.Email);
        Assert.Equal(new DateOnly(1995, 4, 12), p.BirthDate);
        Assert.Equal(Gender.Female, p.Gender);
        Assert.Equal(auth.User.Phone, p.Phone);
        Assert.Null(p.AssignedTrainer);
        Assert.True(p.MemberSince > DateTimeOffset.UtcNow.AddMinutes(-5)); // the "member since" date is the sign-up time
        var me = (await client.GetFromJsonAsync<AuthUserDto>("/api/auth/me", Json))!;
        Assert.Equal("Client", me.Role);

        // Clearing optional fields is allowed.
        (await client.PutAsJsonAsync("/api/me/profile", new { firstName = "Aziza", lastName = "Karimova" }, Json)).EnsureSuccessStatusCode();
        p = (await client.GetFromJsonAsync<ClientProfileDto>("/api/me/profile", Json))!;
        Assert.Null(p.Email);
        Assert.Null(p.BirthDate);
    }

    [Fact]
    public async Task Client_profile_validation_rejects_bad_input()
    {
        var (client, _) = await _s.RegisterClientAsync();
        var res = await client.PutAsJsonAsync("/api/me/profile", new
        {
            firstName = "", lastName = new string('x', 65), email = "not-an-email", birthDate = DateTime.UtcNow.AddDays(2).ToString("yyyy-MM-dd"),
        }, Json);
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        var errors = (await res.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>(Json)).GetProperty("errors");
        foreach (var field in new[] { "FirstName", "LastName", "Email", "BirthDate" })
            Assert.True(errors.TryGetProperty(field, out _), field);
    }

    [Fact]
    public async Task Trainer_edits_own_card_and_clients_see_it()
    {
        var (trainer, t) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var res = await trainer.PutAsJsonAsync("/api/trainer/profile",
            new { specialization = "Йога", bio = "10 лет практики", isAcceptingClients = false }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);

        var (client, _) = await _s.RegisterClientAsync();
        var visible = (await client.GetFromJsonAsync<TrainerPublicDto>($"/api/trainers/{t.Id}", Json))!;
        Assert.Equal("Йога", visible.Specialization);
        Assert.Equal("10 лет практики", visible.Bio);
        Assert.False(visible.IsAcceptingClients);

        // A client cannot use the trainer endpoint.
        var forbidden = await client.PutAsJsonAsync("/api/trainer/profile", new { specialization = "x", isAcceptingClients = true }, Json);
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
    }
}
