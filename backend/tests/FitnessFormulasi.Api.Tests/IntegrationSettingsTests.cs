using System.Net;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Integrations;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace FitnessFormulasi.Api.Tests;

/// <summary>
/// Integration settings share one row per provider, so these tests run in a fixed order inside one test
/// (xUnit runs facts of a class sequentially, but other classes do not touch integrations).
/// </summary>
[Collection(ApiCollection.Name)]
public class IntegrationSettingsTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;
    private const string ClickSecret = "ClickSecret-Value-123";
    private const string ClickSecretNew = "ClickSecret-Replaced-456";
    private const string PaymeKey = "Payme&Key#Prod-789";

    private async Task<HttpClient> AdminWithoutPermissionAsync()
    {
        var phone = ApiFactory.NewPhone();
        using (var scope = factory.Services.CreateScope())
        {
            var auth = scope.ServiceProvider.GetRequiredService<AuthService>();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            await auth.CreateUserAsync(phone, "OtherAdmin123", "Other", "Admin", RoleNames.Admin, default);
            await db.SaveChangesAsync();
        }
        return await factory.LoginAsync(phone, "OtherAdmin123");
    }

    private static async Task<IntegrationDto> ReadAsync(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        return (await res.Content.ReadFromJsonAsync<IntegrationDto>(Json))!;
    }

    [Fact]
    public async Task Only_admins_with_the_permission_can_read_or_change_integrations()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync("/api/admin/integrations")).StatusCode);

        var (client, _) = await _s.RegisterClientAsync();
        var (trainer, _) = await _s.CreateTrainerAsync(await factory.AdminAsync());
        var otherAdmin = await AdminWithoutPermissionAsync();
        foreach (var http in new[] { client, trainer, otherAdmin })
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await http.GetAsync("/api/admin/integrations")).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await http.PutAsJsonAsync("/api/admin/integrations/Click/Test/secrets/secretKey",
                new { value = "Attempt-12345678" }, Json)).StatusCode);
        }

        var me = (await (await otherAdmin.GetAsync("/api/auth/me")).Content.ReadFromJsonAsync<AuthUserDto>(Json))!;
        Assert.False(me.CanManageIntegrations);
        var bootstrap = (await (await (await factory.AdminAsync()).GetAsync("/api/auth/me")).Content.ReadFromJsonAsync<AuthUserDto>(Json))!;
        Assert.True(bootstrap.CanManageIntegrations);
    }

    [Fact]
    public async Task Settings_secrets_status_and_audit_lifecycle()
    {
        var admin = await factory.AdminAsync();

        // Initially nothing is configured and no fake "connected" state is shown.
        var list = (await admin.GetFromJsonAsync<List<IntegrationDto>>("/api/admin/integrations", Json))!;
        Assert.Equal([IntegrationProvider.Click, IntegrationProvider.Payme], list.Select(i => i.Provider));
        var click = list[0];
        Assert.Equal(IntegrationStatus.NotConfigured, click.Status);
        Assert.True(click.EncryptionConfigured);
        Assert.False(click.Test.Secrets["secretKey"].IsSet);

        // Secrets cannot be sent through the regular settings call.
        var smuggled = await admin.PutAsJsonAsync("/api/admin/integrations/Click", new
        {
            isEnabled = false, mode = "Test", test = new Dictionary<string, string> { ["secretKey"] = ClickSecret }, version = click.Version,
        }, Json);
        Assert.Equal(HttpStatusCode.BadRequest, smuggled.StatusCode);

        click = await ReadAsync(await admin.PutAsJsonAsync("/api/admin/integrations/Click", new
        {
            isEnabled = false, mode = "Test",
            test = new Dictionary<string, string> { ["serviceId"] = "12345", ["merchantId"] = "678", ["merchantUserId"] = "910" },
            version = click.Version,
        }, Json));
        Assert.Equal(IntegrationStatus.NotConfigured, click.Status);
        Assert.Equal(["secretKey"], click.Test.MissingFields);

        // Switching on an incomplete configuration is refused with a clear code.
        var incomplete = await admin.PutAsJsonAsync("/api/admin/integrations/Click", new
        {
            isEnabled = true, mode = "Test",
            test = new Dictionary<string, string> { ["serviceId"] = "12345", ["merchantId"] = "678", ["merchantUserId"] = "910" },
            version = click.Version,
        }, Json);
        Assert.Equal(HttpStatusCode.Conflict, incomplete.StatusCode);
        Assert.Equal("integration_incomplete", await Scenario.ErrorCodeAsync(incomplete));

        // Setting the secret: the response shows only a mask, never the value.
        var setRes = await admin.PutAsJsonAsync("/api/admin/integrations/Click/Test/secrets/secretKey", new { value = ClickSecret }, Json);
        var body = await setRes.Content.ReadAsStringAsync();
        Assert.DoesNotContain(ClickSecret, body);
        click = await ReadAsync(setRes);
        Assert.True(click.Test.Secrets["secretKey"].IsSet);
        Assert.Equal("••••••••", click.Test.Secrets["secretKey"].Mask);
        Assert.Equal(IntegrationStatus.Configured, click.Status);

        // Stored encrypted, not as plaintext.
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var stored = await db.IntegrationSecrets.SingleAsync(s => s.Provider == IntegrationProvider.Click && s.Name == "secretKey");
            Assert.StartsWith("v1:", stored.Ciphertext);
            Assert.DoesNotContain(ClickSecret, stored.Ciphertext);
        }

        // Saving other settings without the secret keeps it (an empty field never clears a secret).
        click = await ReadAsync(await admin.PutAsJsonAsync("/api/admin/integrations/Click", new
        {
            isEnabled = true, mode = "Test",
            test = new Dictionary<string, string> { ["serviceId"] = "12345", ["merchantId"] = "678", ["merchantUserId"] = "910" },
            version = click.Version,
        }, Json));
        Assert.True(click.Test.Secrets["secretKey"].IsSet);
        // Switched on but never verified by a real provider request: not "Active".
        Assert.Equal(IntegrationStatus.NeedsVerification, click.Status);
        Assert.Null(click.LastVerifiedAt);

        // A stale version is rejected.
        var stale = await admin.PutAsJsonAsync("/api/admin/integrations/Click", new { isEnabled = false, mode = "Test", version = 1 }, Json);
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);

        // Replacing is an explicit call; removing a secret of the active mode needs the integration switched off first.
        click = await ReadAsync(await admin.PutAsJsonAsync("/api/admin/integrations/Click/Test/secrets/secretKey", new { value = ClickSecretNew }, Json));
        var blocked = await admin.DeleteAsync("/api/admin/integrations/Click/Test/secrets/secretKey");
        Assert.Equal(HttpStatusCode.Conflict, blocked.StatusCode);
        Assert.Equal("integration_enabled", await Scenario.ErrorCodeAsync(blocked));
        click = await ReadAsync(await admin.PutAsJsonAsync("/api/admin/integrations/Click", new
        {
            isEnabled = false, mode = "Test",
            test = new Dictionary<string, string> { ["serviceId"] = "12345", ["merchantId"] = "678", ["merchantUserId"] = "910" },
            version = click.Version,
        }, Json));
        click = await ReadAsync(await admin.DeleteAsync("/api/admin/integrations/Click/Test/secrets/secretKey"));
        Assert.False(click.Test.Secrets["secretKey"].IsSet);
        Assert.Equal(IntegrationStatus.NotConfigured, click.Status);

        // Test and production credentials are separate.
        var payme = await ReadAsync(await admin.PutAsJsonAsync("/api/admin/integrations/Payme/Production/secrets/key", new { value = PaymeKey }, Json));
        Assert.True(payme.Production.Secrets["key"].IsSet);
        Assert.False(payme.Test.Secrets["key"].IsSet);
        var badId = await admin.PutAsJsonAsync("/api/admin/integrations/Payme", new
        {
            isEnabled = false, mode = "Production", production = new Dictionary<string, string> { ["merchantId"] = "not-hex" }, version = payme.Version,
        }, Json);
        Assert.Equal("invalid_field", await Scenario.ErrorCodeAsync(badId));

        // The audit names the changed fields and who changed them, never the values.
        var audit = (await admin.GetFromJsonAsync<List<AuditEntryDto>>("/api/admin/integrations/Click/audit", Json))!;
        Assert.Contains(audit, a => a.Action == "secret_set" && a.Details == "test.secretKey");
        Assert.Contains(audit, a => a.Action == "secret_replaced");
        Assert.Contains(audit, a => a.Action == "secret_removed");
        Assert.All(audit, a => Assert.NotNull(a.UserName));
        var auditText = string.Join("|", audit.Select(a => a.Details));
        Assert.DoesNotContain(ClickSecret, auditText);
        Assert.DoesNotContain(ClickSecretNew, auditText);

        // Nothing secret reached the logs.
        var logs = string.Join("\n", factory.Logs.Lines);
        Assert.Contains("secret_replaced", logs);
        foreach (var secret in new[] { ClickSecret, ClickSecretNew, PaymeKey }) Assert.DoesNotContain(secret, logs);
    }

    [Fact]
    public async Task Without_an_encryption_key_secrets_are_refused()
    {
        using var noKey = factory.WithWebHostBuilder(b => b.UseSetting("Integrations:EncryptionKey", ""));
        var admin = noKey.CreateClient();
        var login = await admin.PostAsJsonAsync("/api/auth/login", new { phone = ApiFactory.AdminPhone, password = await CurrentAdminPasswordAsync() }, Json);
        var auth = (await login.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        admin.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);

        var list = (await admin.GetFromJsonAsync<List<IntegrationDto>>("/api/admin/integrations", Json))!;
        Assert.All(list, i => Assert.False(i.EncryptionConfigured));
        var res = await admin.PutAsJsonAsync("/api/admin/integrations/Payme/Test/secrets/key", new { value = "TestKey-12345678" }, Json);
        Assert.Equal(HttpStatusCode.Conflict, res.StatusCode);
        Assert.Equal("encryption_not_configured", await Scenario.ErrorCodeAsync(res));
    }

    /// <summary>The bootstrap admin's temporary password is replaced on first sign-in by the factory.</summary>
    private async Task<string> CurrentAdminPasswordAsync()
    {
        await factory.AdminAsync();
        return ApiFactory.AdminPassword + "x1";
    }
}
