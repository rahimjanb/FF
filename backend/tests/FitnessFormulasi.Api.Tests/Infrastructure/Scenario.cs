using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Features.Admin;

namespace FitnessFormulasi.Api.Tests.Infrastructure;

/// <summary>Builds test data only through the public API, the same way real clients do.</summary>
public sealed class Scenario(ApiFactory factory)
{
    public const string Password = "Secret123";
    public static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    public async Task<(HttpClient Http, AuthResponse Auth)> RegisterClientAsync(string? phone = null)
    {
        var http = factory.CreateClient();
        var res = await http.PostAsJsonAsync("/api/auth/register",
            new { phone = phone ?? ApiFactory.NewPhone(), password = Password, firstName = "Test", lastName = "Client" }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var auth = (await res.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return (http, auth);
    }

    public async Task<Guid> ClientIdAsync(HttpClient client) =>
        (await client.GetFromJsonAsync<ClientProfileDto>("/api/me/profile", Json))!.Id;

    public async Task<(HttpClient Http, TrainerAdminDto Trainer)> CreateTrainerAsync(HttpClient admin, bool accepting = true)
    {
        var phone = ApiFactory.NewPhone();
        var res = await admin.PostAsJsonAsync("/api/admin/trainers",
            new { phone, password = Password, firstName = "Coach", lastName = "T", specialization = "Strength" }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        var trainer = (await res.Content.ReadFromJsonAsync<TrainerAdminDto>(Json))!;
        if (!accepting)
        {
            (await admin.PutAsJsonAsync($"/api/admin/trainers/{trainer.Id}", new
            {
                phone, firstName = "Coach", lastName = "T", isAcceptingClients = false, isActive = true, status = "Active",
            }, Json)).EnsureSuccessStatusCode();
        }
        return (await factory.LoginAsync(phone, Password), trainer);
    }

    public async Task<MembershipPlanDto> CreatePlanAsync(HttpClient admin, int days = 30, int? visitLimit = null)
    {
        var res = await admin.PostAsJsonAsync("/api/admin/membership-plans", new
        {
            name = "Plan " + Guid.NewGuid().ToString("N")[..8],
            type = visitLimit is null ? "Unlimited" : "LimitedVisits",
            durationDays = days, visitLimit, price = 300000,
        }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<MembershipPlanDto>(Json))!;
    }

    public async Task<HttpResponseMessage> AssignAsync(HttpClient admin, Guid clientId, Guid planId, DateOnly? start = null) =>
        await admin.PostAsJsonAsync("/api/admin/memberships", new { clientId, planId, startDate = start }, Json);

    public async Task<TrainerRequestDto> RequestTrainerAsync(HttpClient client, Guid trainerId)
    {
        var res = await client.PostAsJsonAsync("/api/me/trainer-requests", new { trainerId, message = "Hi" }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<TrainerRequestDto>(Json))!;
    }

    public static async Task<string?> ErrorCodeAsync(HttpResponseMessage res)
    {
        var body = await res.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>(Json);
        return body.TryGetProperty("code", out var c) ? c.GetString() : null;
    }

    public static DateOnly Today(ApiFactory f) =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(f.Clock.Now, TimeZoneInfo.FindSystemTimeZoneById("Asia/Tashkent")).DateTime);

    public static MembershipEffectiveStatus Status(MembershipDto m) => m.EffectiveStatus;
}
