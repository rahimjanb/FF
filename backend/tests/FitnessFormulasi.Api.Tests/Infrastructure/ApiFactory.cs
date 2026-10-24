using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FitnessFormulasi.Api.Auth;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Testcontainers.PostgreSql;

namespace FitnessFormulasi.Api.Tests.Infrastructure;

/// <summary>
/// Controllable clock so membership dates and lockouts can be tested deterministically.
/// Starts at real time because JWT lifetime validation (Microsoft.IdentityModel) uses the system clock.
/// </summary>
public sealed class TestTimeProvider : TimeProvider
{
    public DateTimeOffset Now { get; set; } = DateTimeOffset.UtcNow;
    public override DateTimeOffset GetUtcNow() => Now;
}

/// <summary>
/// Runs the real API against a throwaway PostgreSQL container. Environment is "Testing", so
/// Development-only components (SMS logger, Swagger) are not registered — same as Production.
/// </summary>
public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string AdminPhone = "+998900000001";
    public const string AdminPassword = "AdminPass123";

    private readonly PostgreSqlContainer _db = new PostgreSqlBuilder("postgres:17-alpine").Build();
    public TestTimeProvider Clock { get; } = new();

    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { Converters = { new JsonStringEnumConverter() } };

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Default", _db.GetConnectionString());
        builder.UseSetting("Jwt:SigningKey", "test-signing-key-test-signing-key-0123456789");
        builder.UseSetting("Database:MigrateOnStartup", "true");
        builder.UseSetting("Bootstrap:AdminPhone", AdminPhone);
        builder.UseSetting("Bootstrap:AdminPassword", AdminPassword);
        builder.UseSetting("RateLimiting:AuthPermitPerMinute", "100000");
        builder.ConfigureServices(s =>
        {
            s.RemoveAll<TimeProvider>();
            s.AddSingleton<TimeProvider>(Clock);
        });
    }

    public async Task InitializeAsync() => await _db.StartAsync();

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();
        await _db.DisposeAsync();
    }

    // Passwords replaced during the test run (temporary passwords set by staff must be changed at first sign-in).
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string, string> _changedPasswords = new();

    /// <summary>
    /// Signs in and, if the account still has a staff-assigned temporary password, completes the mandatory
    /// change so the returned client can call regular endpoints. Use <see cref="RawLoginAsync"/> to test the gate itself.
    /// </summary>
    public async Task<HttpClient> LoginAsync(string phone, string password)
    {
        var current = _changedPasswords.GetValueOrDefault(phone, password);
        var (client, auth) = await RawLoginAsync(phone, current);
        if (!auth.User.MustChangePassword) return client;

        var newPassword = current + "x1";
        var res = await client.PostAsJsonAsync("/api/auth/change-password", new { currentPassword = current, newPassword }, Json);
        res.EnsureSuccessStatusCode();
        _changedPasswords[phone] = newPassword;
        var changed = (await res.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", changed.AccessToken);
        return client;
    }

    public async Task<(HttpClient Client, AuthResponse Auth)> RawLoginAsync(string phone, string password)
    {
        var client = CreateClient();
        var res = await client.PostAsJsonAsync("/api/auth/login", new { phone, password }, Json);
        res.EnsureSuccessStatusCode();
        var auth = (await res.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return (client, auth);
    }

    public Task<HttpClient> AdminAsync() => LoginAsync(AdminPhone, AdminPassword);

    public static string NewPhone() => "+99891" + Random.Shared.Next(1000000, 9999999);
}

[CollectionDefinition(Name)]
public class ApiCollection : ICollectionFixture<ApiFactory>
{
    public const string Name = "api";
}
