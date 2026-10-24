using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Features.Admin;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

/// <summary>Temporary passwords assigned by staff must be replaced before the account can be used.</summary>
[Collection(ApiCollection.Name)]
public class PasswordChangeTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private async Task<(string Phone, Guid ClientId)> AdminCreatesClientAsync(HttpClient admin, string password = "Temp12345")
    {
        var phone = ApiFactory.NewPhone();
        var res = await admin.PostAsJsonAsync("/api/admin/clients", new { phone, password, firstName = "Staff", lastName = "Made" }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return (phone, (await res.Content.ReadFromJsonAsync<ClientAdminDto>(Json))!.Id);
    }

    [Fact]
    public async Task Admin_created_client_must_change_password_before_using_the_app()
    {
        var admin = await factory.AdminAsync();
        var (phone, _) = await AdminCreatesClientAsync(admin);

        var (client, auth) = await factory.RawLoginAsync(phone, "Temp12345");
        Assert.True(auth.User.MustChangePassword);

        var blocked = await client.GetAsync("/api/me/dashboard");
        Assert.Equal(HttpStatusCode.Forbidden, blocked.StatusCode);
        Assert.Equal("password_change_required", await Scenario.ErrorCodeAsync(blocked));
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/auth/me")).StatusCode);

        var same = await client.PostAsJsonAsync("/api/auth/change-password", new { currentPassword = "Temp12345", newPassword = "Temp12345" }, Json);
        Assert.Equal("password_unchanged", await Scenario.ErrorCodeAsync(same));
        var wrong = await client.PostAsJsonAsync("/api/auth/change-password", new { currentPassword = "Nope12345", newPassword = "Mine12345" }, Json);
        Assert.Equal("invalid_password", await Scenario.ErrorCodeAsync(wrong));

        var changed = await client.PostAsJsonAsync("/api/auth/change-password", new { currentPassword = "Temp12345", newPassword = "Mine12345" }, Json);
        Assert.Equal(HttpStatusCode.OK, changed.StatusCode);
        var fresh = (await changed.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        Assert.False(fresh.User.MustChangePassword);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", fresh.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/me/dashboard")).StatusCode);

        // The old session is revoked; the temporary password no longer works.
        var oldRefresh = await factory.CreateClient().PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, oldRefresh.StatusCode);
        var oldLogin = await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { phone, password = "Temp12345" }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, oldLogin.StatusCode);
        var (_, again) = await factory.RawLoginAsync(phone, "Mine12345");
        Assert.False(again.User.MustChangePassword);
    }

    [Fact]
    public async Task Self_registered_client_is_not_asked_to_change_password()
    {
        var (_, auth) = await _s.RegisterClientAsync();
        Assert.False(auth.User.MustChangePassword);
    }

    [Fact]
    public async Task Admin_reset_requires_a_new_change_and_ends_sessions()
    {
        var (client, reg) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);
        var admin = await factory.AdminAsync();

        var reset = await admin.PostAsJsonAsync($"/api/admin/clients/{clientId}/reset-password", new { newPassword = "Reset12345" }, Json);
        Assert.Equal(HttpStatusCode.NoContent, reset.StatusCode);

        var refresh = await factory.CreateClient().PostAsJsonAsync("/api/auth/refresh", new { refreshToken = reg.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
        var (_, auth) = await factory.RawLoginAsync(reg.User.Phone, "Reset12345");
        Assert.True(auth.User.MustChangePassword);
    }

    [Fact]
    public async Task Trainer_created_by_admin_is_gated_until_password_change()
    {
        var admin = await factory.AdminAsync();
        var phone = ApiFactory.NewPhone();
        (await admin.PostAsJsonAsync("/api/admin/trainers",
            new { phone, password = "Temp12345", firstName = "New", lastName = "Coach" }, Json)).EnsureSuccessStatusCode();

        var (trainer, auth) = await factory.RawLoginAsync(phone, "Temp12345");
        Assert.True(auth.User.MustChangePassword);
        var blocked = await trainer.GetAsync("/api/trainer/requests");
        Assert.Equal("password_change_required", await Scenario.ErrorCodeAsync(blocked));
    }
}
