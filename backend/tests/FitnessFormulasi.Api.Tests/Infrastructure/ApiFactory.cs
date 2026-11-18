using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FitnessFormulasi.Api.Auth;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
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

    /// <summary>Test-only AES-256 key for integration secrets (32 zero-free bytes, base64).</summary>
    public static readonly string IntegrationsKey = Convert.ToBase64String(Enumerable.Range(1, 32).Select(i => (byte)i).ToArray());

    /// <summary>Every log line the API writes during the run, to assert that secrets never reach the logs.</summary>
    public CapturingLoggerProvider Logs { get; } = new();

    /// <summary>Uploaded banner files of this run; removed when the factory is disposed.</summary>
    public string MediaRoot { get; } = Path.Combine(Path.GetTempPath(), "ff-tests-media-" + Guid.NewGuid().ToString("N"));

    /// <summary>Face recognition terminals the API talks to during the run.</summary>
    public FakeTerminals Terminals { get; } = new();

    /// <summary>The AI provider (scripted answers, no tokens spent) and the external food databases.</summary>
    public FakeAi Ai { get; } = new();
    public FakeFoodSources FoodSources { get; } = new();
    /// <summary>The OpenAI API behind keys set in the admin panel (the server's own provider is <see cref="Ai"/>).</summary>
    public FakeOpenAi OpenAi { get; } = new();

    /// <summary>AI photo scans a client may make per day in this run.</summary>
    public const int PhotoScansPerDay = 6;

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
        builder.UseSetting("Integrations:EncryptionKey", IntegrationsKey);
        builder.UseSetting("Media:RootPath", MediaRoot);
        builder.UseSetting("Access:BackgroundSync", "false"); // tests synchronise explicitly
        builder.UseSetting("Legal:OperatorName", "ООО \"Fitness <Test>\"");
        builder.UseSetting("RateLimiting:AiPermitPerMinute", "100000");
        builder.UseSetting("RateLimiting:LookupPermitPerMinute", "100000");
        builder.UseSetting("Ai:PhotoScansPerDay", PhotoScansPerDay.ToString());
        builder.UseSetting("Ai:MonthlyBudgetUsd", "0");
        builder.ConfigureLogging(l => l.AddProvider(Logs));
        builder.ConfigureServices(s =>
        {
            s.RemoveAll<TimeProvider>();
            s.AddSingleton<TimeProvider>(Clock);
            s.RemoveAll<FitnessFormulasi.Api.Features.Access.IIsapiHandlerFactory>();
            s.AddSingleton<FitnessFormulasi.Api.Features.Access.IIsapiHandlerFactory>(Terminals);
            s.RemoveAll<FitnessFormulasi.Api.Features.Ai.IAiModelClient>();
            s.AddSingleton<FitnessFormulasi.Api.Features.Ai.IAiModelClient>(Ai);
            s.AddHttpClient(FitnessFormulasi.Api.Features.Ai.OpenAiClient.HttpClientName).ConfigurePrimaryHttpMessageHandler(() => OpenAi);
            s.RemoveAll<FitnessFormulasi.Api.Features.Nutrition.IBarcodeProductSource>();
            s.AddSingleton<FitnessFormulasi.Api.Features.Nutrition.IBarcodeProductSource>(FoodSources);
            s.RemoveAll<FitnessFormulasi.Api.Features.Nutrition.IFoodSearchSource>();
            s.AddSingleton<FitnessFormulasi.Api.Features.Nutrition.IFoodSearchSource>(FoodSources);
        });
    }

    public async Task InitializeAsync() => await _db.StartAsync();

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();
        await _db.DisposeAsync();
        if (Directory.Exists(MediaRoot)) Directory.Delete(MediaRoot, recursive: true);
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

public sealed class CapturingLoggerProvider : ILoggerProvider
{
    public System.Collections.Concurrent.ConcurrentQueue<string> Lines { get; } = new();

    public ILogger CreateLogger(string categoryName) => new Logger(this);
    public void Dispose() { }

    private sealed class Logger(CapturingLoggerProvider owner) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            owner.Lines.Enqueue(formatter(state, exception) + " " + exception);
    }
}
