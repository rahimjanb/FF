using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Integrations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>What a provider client is built from.</summary>
public sealed record AiClientSettings(string ApiKey, string? BaseUrl, int TimeoutSeconds, int MaxRetries, bool RefusalFallback)
{
    /// <summary>
    /// The key and URL for <paramref name="provider"/> from the "Ai" section: the key only when it is the configured
    /// provider; the URL from Ai:OpenAiBaseUrl / Ai:AnthropicBaseUrl, or Ai:BaseUrl for the configured provider.
    /// </summary>
    public static AiClientSettings FromOptions(AiOptions o, string provider, string? apiKey = null)
    {
        var configured = string.Equals(o.Provider, provider, StringComparison.OrdinalIgnoreCase);
        var key = apiKey ?? (configured && o.IsEnabled ? o.ApiKey! : "");
        var specific = provider == AiProviders.OpenAI ? o.OpenAiBaseUrl : o.AnthropicBaseUrl;
        var url = !string.IsNullOrWhiteSpace(specific) ? specific : configured && !string.IsNullOrWhiteSpace(o.BaseUrl) ? o.BaseUrl : null;
        return new AiClientSettings(key, url, o.TimeoutSeconds, o.MaxRetries, o.RefusalFallback);
    }
}

public sealed class AiClientFactory(IHttpClientFactory http, ILoggerFactory logs)
{
    public IAiModelClient Create(string provider, AiClientSettings settings) => provider switch
    {
        AiProviders.OpenAI => new OpenAiClient(settings, http, logs.CreateLogger<OpenAiClient>()),
        AiProviders.Anthropic => new AnthropicAiClient(settings, logs.CreateLogger<AnthropicAiClient>()),
        _ => new DisabledAiClient(),
    };
}

/// <summary>Where the provider in use comes from: nowhere (AI off), the server configuration or the admin panel.</summary>
public enum AiSettingsSource { None, Server, Admin }

/// <summary>The provider that serves AI requests now, with its models and the monthly budget.</summary>
public sealed record AiConnection(
    IAiModelClient Client, string VisionModel, string ChatModel, string VisionEffort, string ChatEffort, decimal MonthlyBudgetUsd,
    AiSettingsSource Source)
{
    public bool IsConfigured => Client.IsConfigured;
    public string Provider => Client.ProviderId;
    public string? DisplayName => Client.IsConfigured ? Client.DisplayName : null;
    public string ModelFor(AiFeature feature) => feature is AiFeature.FoodPhoto or AiFeature.FoodLabel ? VisionModel : ChatModel;
    public string EffortFor(AiFeature feature) => feature is AiFeature.FoodPhoto or AiFeature.FoodLabel ? VisionEffort : ChatEffort;
}

/// <summary>
/// Decides which provider serves AI requests: the admin panel settings when switched on there with a readable key,
/// otherwise the server configuration (the <see cref="IAiModelClient"/> registered from the "Ai" section). The answer is
/// kept for a short time; saving the settings in the admin panel clears it at once.
/// </summary>
public sealed class AiConnectionProvider(
    IServiceScopeFactory scopes, IAiModelClient serverClient, AiClientFactory factory, SecretProtector protector,
    IOptions<AiOptions> options, ILogger<AiConnectionProvider> logger)
{
    private const long TtlMs = 30_000;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private readonly ConcurrentDictionary<string, IAiModelClient> _clients = new();
    private Cached? _cached;
    private long _generation;

    private sealed record Cached(AiConnection Connection, long Generation, long At);

    /// <summary>The admin settings changed: the next request reads them again.</summary>
    public void Invalidate()
    {
        Interlocked.Increment(ref _generation);
        _clients.Clear();
    }

    public async Task<AiConnection> GetAsync(CancellationToken ct)
    {
        var generation = Volatile.Read(ref _generation);
        if (_cached is { } hit && hit.Generation == generation && Environment.TickCount64 - hit.At < TtlMs) return hit.Connection;
        await _lock.WaitAsync(ct);
        try
        {
            generation = Volatile.Read(ref _generation);
            if (_cached is { } again && again.Generation == generation && Environment.TickCount64 - again.At < TtlMs)
                return again.Connection;
            var connection = await LoadAsync(ct);
            _cached = new Cached(connection, generation, Environment.TickCount64);
            return connection;
        }
        finally
        {
            _lock.Release();
        }
    }

    /// <summary>A client for a key set in the admin panel (reused while the key is the same).</summary>
    public IAiModelClient ClientFor(string provider, string apiKey)
    {
        var id = provider + ":" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(apiKey)));
        return _clients.GetOrAdd(id, _ => factory.Create(provider, AiClientSettings.FromOptions(options.Value, provider, apiKey)));
    }

    /// <summary>The decrypted key of a provider, or null when it is not set or no longer decrypts (the server key changed).</summary>
    public string? KeyOf(AiProviderSettings settings, string provider)
    {
        var ciphertext = provider == AiProviders.OpenAI ? settings.OpenAiKeyCiphertext : settings.AnthropicKeyCiphertext;
        return ciphertext is null ? null : protector.Unprotect(ciphertext, KeyContext(provider));
    }

    public static string KeyContext(string provider) => $"ai/{provider}/apiKey";

    public AiConnection Connect(AiProviderSettings settings, string apiKey)
    {
        var o = options.Value;
        var info = AiProviders.Find(settings.Provider)!;
        return new AiConnection(ClientFor(info.Id, apiKey), settings.VisionModel ?? info.DefaultVisionModel,
            settings.ChatModel ?? info.DefaultChatModel, o.VisionEffort, o.ChatEffort, settings.MonthlyBudgetUsd ?? o.MonthlyBudgetUsd,
            AiSettingsSource.Admin);
    }

    private async Task<AiConnection> LoadAsync(CancellationToken ct)
    {
        using (var scope = scopes.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var settings = await db.AiProviderSettings.AsNoTracking().OrderBy(s => s.CreatedAt).FirstOrDefaultAsync(ct);
            if (settings is { IsEnabled: true } && AiProviders.Find(settings.Provider) is not null)
            {
                if (KeyOf(settings, settings.Provider) is { } key) return Connect(settings, key);
                logger.LogWarning("AI provider {Provider} is switched on in the admin panel, but its API key does not decrypt " +
                                  "(Integrations__EncryptionKey changed?). Using the server configuration; enter the key again", settings.Provider);
            }
        }

        var o = options.Value;
        var info = AiProviders.Find(serverClient.ProviderId);
        return new AiConnection(serverClient,
            Model(o.VisionModel, info?.DefaultVisionModel), Model(o.ChatModel, info?.DefaultChatModel), o.VisionEffort, o.ChatEffort,
            o.MonthlyBudgetUsd, serverClient.IsConfigured ? AiSettingsSource.Server : AiSettingsSource.None);
    }

    private static string Model(string? configured, string? fallback) =>
        !string.IsNullOrWhiteSpace(configured) ? configured.Trim() : fallback ?? "default";
}
