using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace FitnessFormulasi.Api.Tests;

[Collection(ApiCollection.Name)]
public class AuthTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    [Fact]
    public async Task Register_then_login_returns_client_role_and_password_is_hashed()
    {
        var phone = ApiFactory.NewPhone();
        var (_, reg) = await _s.RegisterClientAsync(phone);
        Assert.Equal("Client", reg.User.Role);
        Assert.False(reg.User.PhoneConfirmed);

        var login = await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { phone, password = Scenario.Password }, Json);
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);

        using var scope = factory.Services.CreateScope();
        var user = await scope.ServiceProvider.GetRequiredService<AppDbContext>().Users.SingleAsync(u => u.Phone == phone);
        Assert.DoesNotContain(Scenario.Password, user.PasswordHash);
        Assert.StartsWith("AQAAAA", user.PasswordHash); // ASP.NET Identity v3 (PBKDF2) format
    }

    [Fact]
    public async Task Register_accepts_local_format_and_rejects_duplicate_phone()
    {
        var local = "93" + Random.Shared.Next(1000000, 9999999);
        await _s.RegisterClientAsync(local);
        var dup = await factory.CreateClient().PostAsJsonAsync("/api/auth/register",
            new { phone = "+998" + local, password = Scenario.Password, firstName = "A", lastName = "B" }, Json);
        Assert.Equal(HttpStatusCode.Conflict, dup.StatusCode);
        Assert.Equal("phone_taken", await Scenario.ErrorCodeAsync(dup));
    }

    [Fact]
    public async Task Register_validates_input()
    {
        var res = await factory.CreateClient().PostAsJsonAsync("/api/auth/register",
            new { phone = "123", password = "short", firstName = "", lastName = "B" }, Json);
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        var body = await res.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>(Json);
        Assert.Equal("validation_failed", body.GetProperty("code").GetString());
        var errors = body.GetProperty("errors");
        Assert.True(errors.TryGetProperty("Phone", out _));
        Assert.True(errors.TryGetProperty("Password", out _));
        Assert.True(errors.TryGetProperty("FirstName", out _));
    }

    [Fact]
    public async Task Short_dev_logins_are_rejected_outside_development()
    {
        Assert.Null(factory.Services.GetService<DevLogins>());
        var res = await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { phone = "1", password = "1" }, Json);
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        Assert.Equal("validation_failed", await Scenario.ErrorCodeAsync(res));
    }

    [Fact]
    public async Task Wrong_password_and_unknown_phone_give_same_error()
    {
        var phone = ApiFactory.NewPhone();
        await _s.RegisterClientAsync(phone);
        var http = factory.CreateClient();
        var wrong = await http.PostAsJsonAsync("/api/auth/login", new { phone, password = "Wrong1234" }, Json);
        var unknown = await http.PostAsJsonAsync("/api/auth/login", new { phone = ApiFactory.NewPhone(), password = "Wrong1234" }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, unknown.StatusCode);
        Assert.Equal("invalid_credentials", await Scenario.ErrorCodeAsync(wrong));
        Assert.Equal("invalid_credentials", await Scenario.ErrorCodeAsync(unknown));
    }

    [Fact]
    public async Task Account_locks_after_repeated_failures_and_unlocks_later()
    {
        var phone = ApiFactory.NewPhone();
        await _s.RegisterClientAsync(phone);
        var http = factory.CreateClient();
        for (var i = 0; i < AuthService.MaxFailedAttempts; i++)
            await http.PostAsJsonAsync("/api/auth/login", new { phone, password = "Wrong1234" }, Json);

        var locked = await http.PostAsJsonAsync("/api/auth/login", new { phone, password = Scenario.Password }, Json);
        Assert.Equal(HttpStatusCode.Locked, locked.StatusCode);

        var saved = factory.Clock.Now;
        try
        {
            factory.Clock.Now = saved + AuthService.LockoutDuration + TimeSpan.FromMinutes(1);
            var ok = await http.PostAsJsonAsync("/api/auth/login", new { phone, password = Scenario.Password }, Json);
            Assert.Equal(HttpStatusCode.OK, ok.StatusCode);
        }
        finally { factory.Clock.Now = saved; }
    }

    [Fact]
    public async Task Refresh_rotates_and_reuse_revokes_all_sessions()
    {
        var (_, reg) = await _s.RegisterClientAsync();
        var http = factory.CreateClient();

        var first = await http.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = reg.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var rotated = (await first.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        Assert.NotEqual(reg.RefreshToken, rotated.RefreshToken);

        // Old token reused: rejected, and the new one is revoked too (theft detection).
        var reuse = await http.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = reg.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, reuse.StatusCode);
        var afterReuse = await http.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = rotated.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, afterReuse.StatusCode);
    }

    [Fact]
    public async Task Logout_revokes_refresh_token()
    {
        var (http, reg) = await _s.RegisterClientAsync();
        var res = await http.PostAsJsonAsync("/api/auth/logout", new { refreshToken = reg.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.NoContent, res.StatusCode);
        var refresh = await factory.CreateClient().PostAsJsonAsync("/api/auth/refresh", new { refreshToken = reg.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
    }

    [Fact]
    public async Task Blocked_user_loses_access_immediately()
    {
        var (client, _) = await _s.RegisterClientAsync();
        var profile = await client.GetFromJsonAsync<FitnessFormulasi.Api.Features.ClientProfileDto>("/api/me/profile", Json);
        var admin = await factory.AdminAsync();
        var block = await admin.PutAsJsonAsync($"/api/admin/clients/{profile!.Id}", new
        {
            phone = profile.Phone, firstName = profile.FirstName, lastName = profile.LastName, status = "Blocked",
        }, Json);
        Assert.Equal(HttpStatusCode.OK, block.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/me/profile")).StatusCode);
    }

    [Fact]
    public async Task Expired_access_token_is_rejected()
    {
        var (client, _) = await _s.RegisterClientAsync();
        // JwtBearer validates lifetime against the real clock, so craft an already-expired token.
        {
            var handler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
            var token = handler.WriteToken(new System.IdentityModel.Tokens.Jwt.JwtSecurityToken(
                "fitness-formulasi", "fitness-formulasi-clients", [],
                DateTime.UtcNow.AddHours(-2), DateTime.UtcNow.AddHours(-1),
                new Microsoft.IdentityModel.Tokens.SigningCredentials(
                    new Microsoft.IdentityModel.Tokens.SymmetricSecurityKey("test-signing-key-test-signing-key-0123456789"u8.ToArray()),
                    Microsoft.IdentityModel.Tokens.SecurityAlgorithms.HmacSha256)));
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/me/profile")).StatusCode);
        }
    }

    [Fact]
    public async Task Sms_verification_is_unavailable_without_provider()
    {
        var (client, _) = await _s.RegisterClientAsync();
        var res = await client.PostAsync("/api/auth/phone-verification/request", null);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, res.StatusCode);
        Assert.Equal("sms_not_configured", await Scenario.ErrorCodeAsync(res));
    }

    [Fact]
    public async Task Health_endpoint_reports_database()
    {
        var res = await factory.CreateClient().GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.Equal("Healthy", await res.Content.ReadAsStringAsync());
    }
}
