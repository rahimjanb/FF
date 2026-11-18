using System.Text.Json;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>
/// AI settings (section "Ai"). The provider and its API key can be set in two places: the admin panel (Settings →
/// Integrations → AI, the key stored encrypted; wins when switched on there) or this section (environment variables
/// <c>Ai__Provider</c>, <c>Ai__ApiKey</c>; never appsettings or source code). Without either every AI feature is off:
/// the app shows that photo analysis is not connected, the diary, barcodes and manual search keep working.
/// </summary>
public sealed class AiOptions
{
    public const string Section = "Ai";

    /// <summary>"OpenAI" (ChatGPT), "Anthropic" (Claude) or "None".</summary>
    public string Provider { get; set; } = AiProviders.None;
    public string? ApiKey { get; set; }
    /// <summary>Optional gateway/proxy URL in front of the API of <see cref="Provider"/>.</summary>
    public string? BaseUrl { get; set; }
    /// <summary>Optional API URL per provider (a proxy or a local stand-in); also used for keys set in the admin panel.</summary>
    public string? OpenAiBaseUrl { get; set; }
    public string? AnthropicBaseUrl { get; set; }
    /// <summary>Model for food photos and labels (vision + structured JSON). Empty: the provider's default (<see cref="AiProviders"/>).</summary>
    public string? VisionModel { get; set; }
    /// <summary>Model for the nutrition consultant and the reports. Empty: the provider's default.</summary>
    public string? ChatModel { get; set; }
    /// <summary>Reasoning effort: low, medium, high, xhigh, max (both providers). Lower is faster and cheaper.</summary>
    public string VisionEffort { get; set; } = "medium";
    public string ChatEffort { get; set; } = "medium";
    public int TimeoutSeconds { get; set; } = 90;
    /// <summary>Retries of one request on 408/409/429/5xx and network errors, with backoff.</summary>
    public int MaxRetries { get; set; } = 2;
    public int VisionMaxTokens { get; set; } = 16000;
    public int ChatMaxTokens { get; set; } = 16000;
    /// <summary>Claude only: if the model declines a request for policy reasons, the API retries it on its default substitute model.</summary>
    public bool RefusalFallback { get; set; } = true;

    /// <summary>Per client per club-local day. 0 = no limit.</summary>
    public int PhotoScansPerDay { get; set; } = 30;
    public int LabelScansPerDay { get; set; } = 30;
    public int ChatMessagesPerDay { get; set; } = 60;
    public int ReportsPerDay { get; set; } = 10;
    /// <summary>Spending cap for all clients in a calendar month, USD. 0 = no cap. The admin panel can override it.</summary>
    public decimal MonthlyBudgetUsd { get; set; } = 100;

    /// <summary>
    /// USD per million tokens, by model id (a dated snapshot id such as gpt-6.1-terra-2026-10-26 uses the price of its
    /// model). Configurable, so a price change needs no new release: <c>Ai__Prices__{model}__InputPerMTok</c> and so on.
    /// </summary>
    public Dictionary<string, AiModelPrice> Prices { get; set; } = new()
    {
        ["claude-opus-5-5"] = new() { InputPerMTok = 4m, OutputPerMTok = 20m, CacheReadPerMTok = 0.20m, CacheWritePerMTok = 5m },
        ["claude-sonnet-5-5"] = new() { InputPerMTok = 2m, OutputPerMTok = 10m, CacheReadPerMTok = 0.20m, CacheWritePerMTok = 2.5m },
        ["claude-haiku-5-5"] = new() { InputPerMTok = 0.10m, OutputPerMTok = 0.50m, CacheReadPerMTok = 0.01m, CacheWritePerMTok = 0.125m },
        // OpenAI standard prices (developers.openai.com/api/docs/pricing, November 2026). Cached input is billed lower,
        // cache writes are free.
        ["gpt-6.2-astra"] = new() { InputPerMTok = 8m, OutputPerMTok = 40m, CacheReadPerMTok = 0.40m },
        ["gpt-6.2-sol"] = new() { InputPerMTok = 2m, OutputPerMTok = 10m, CacheReadPerMTok = 0.10m },
        ["gpt-6.1-terra"] = new() { InputPerMTok = 1m, OutputPerMTok = 5m, CacheReadPerMTok = 0.05m },
        ["gpt-6-luna"] = new() { InputPerMTok = 0.10m, OutputPerMTok = 0.50m, CacheReadPerMTok = 0.01m },
    };

    public bool IsEnabled => !string.Equals(Provider, AiProviders.None, StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(ApiKey);
}

/// <summary>A supported AI provider: names for people, default models and the models offered in the admin panel.</summary>
public sealed record AiProviderInfo(
    string Id, string DisplayName, string LegalName, string DefaultVisionModel, string DefaultChatModel, IReadOnlyList<string> Models,
    string KeysUrl);

public static class AiProviders
{
    public const string OpenAI = "OpenAI", Anthropic = "Anthropic", None = "None";

    public static readonly IReadOnlyList<AiProviderInfo> All =
    [
        // GPT-6.1 Terra: OpenAI's model for visual reasoning (matching product photos to catalog entries), and cheap;
        // GPT-6.2 Sol: balanced intelligence and cost, with function tools through the Responses API.
        new(OpenAI, "OpenAI (ChatGPT)", "OpenAI (США), модели ChatGPT через OpenAI API", "gpt-6.1-terra", "gpt-6.2-sol",
            ["gpt-6.1-terra", "gpt-6.2-sol", "gpt-6.2-astra", "gpt-6-luna"], "https://platform.openai.com/api-keys"),
        new(Anthropic, "Anthropic (Claude)", "Anthropic PBC (США), сервис Claude", "claude-opus-5-5", "claude-opus-5-5",
            ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"], "https://console.anthropic.com/settings/keys"),
    ];

    public static AiProviderInfo? Find(string? id) =>
        All.FirstOrDefault(p => string.Equals(p.Id, id, StringComparison.OrdinalIgnoreCase));
}

public sealed class AiModelPrice
{
    public decimal InputPerMTok { get; set; }
    public decimal OutputPerMTok { get; set; }
    public decimal CacheReadPerMTok { get; set; }
    public decimal CacheWritePerMTok { get; set; }
}

public record AiImage(byte[] Data, string MediaType);

public record AiUsage(int InputTokens, int OutputTokens, int CacheReadTokens, int CacheWriteTokens)
{
    public static readonly AiUsage None = new(0, 0, 0, 0);
    public AiUsage Add(AiUsage o) => new(InputTokens + o.InputTokens, OutputTokens + o.OutputTokens,
        CacheReadTokens + o.CacheReadTokens, CacheWriteTokens + o.CacheWriteTokens);
}

/// <summary>
/// One request for a JSON answer that must follow <see cref="Schema"/> (JSON Schema object). <see cref="System"/> is
/// the stable instruction text (cached by providers that support it); <see cref="UserText"/> the per-request part.
/// </summary>
public record AiJsonRequest(
    AiFeature Feature, string System, string UserText, IReadOnlyList<AiImage> Images, JsonObject Schema, int MaxTokens)
{
    /// <summary>Set by <see cref="AiGateway"/> from the provider in use.</summary>
    public string Model { get; init; } = "";
    public string Effort { get; init; } = "";
}

public record AiJsonResponse(string Json, string Model, AiUsage Usage, TimeSpan Duration)
{
    /// <summary>The AiUsage row recorded for this request (set by <see cref="AiGateway"/>).</summary>
    public Guid? UsageId { get; init; }
}

public record AiToolDefinition(string Name, string Description, JsonObject InputSchema);

public record AiToolCall(string Name, JsonElement Input);

public record AiChatMessage(string Role, string Text);

public record AiChatRequest(
    AiFeature Feature, string System, IReadOnlyList<AiChatMessage> Messages, IReadOnlyList<AiToolDefinition> Tools, int MaxTokens,
    int MaxToolRounds)
{
    /// <summary>Set by <see cref="AiGateway"/> from the provider in use.</summary>
    public string Model { get; init; } = "";
    public string Effort { get; init; } = "";
}

public record AiChatResponse(string Text, string Model, AiUsage Usage, TimeSpan Duration, IReadOnlyList<string> ToolsUsed);

/// <summary>
/// The AI provider seen by the business logic. Implementations: <see cref="OpenAiClient"/> (ChatGPT),
/// <see cref="AnthropicAiClient"/> (Claude) and <see cref="DisabledAiClient"/>; tests use a fake. Business code never
/// references a provider API: it goes through <see cref="AiGateway"/>, which picks the provider in use.
/// </summary>
public interface IAiModelClient
{
    /// <summary>Provider name shown to the client in the consent text, e.g. "OpenAI (ChatGPT)".</summary>
    string DisplayName { get; }
    string ProviderId { get; }
    bool IsConfigured { get; }

    Task<AiJsonResponse> GenerateJsonAsync(AiJsonRequest request, CancellationToken ct);

    /// <summary>A conversation in which the model may call <see cref="AiChatRequest.Tools"/>; <paramref name="runTool"/> answers them.</summary>
    Task<AiChatResponse> ChatAsync(AiChatRequest request, Func<AiToolCall, CancellationToken, Task<string>> runTool, CancellationToken ct);
}

/// <summary>
/// AI failure with a stable code for the app. Usage carries the tokens already spent (so they are still counted).
/// <see cref="Detail"/> is what the provider said, for the operator (logs, the admin panel check); never sent to clients.
/// </summary>
public sealed class AiException(int statusCode, string code, string message, AiUsage? usage = null, string? model = null)
    : ApiException(statusCode, code, message)
{
    public AiUsage Usage { get; } = usage ?? AiUsage.None;
    public string? Model { get; } = model;
    /// <summary>HTTP status and error code of the provider's answer, when there was one.</summary>
    public int? ProviderStatus { get; private set; }
    public string? ProviderCode { get; private set; }
    public string? Detail { get; private set; }

    public AiException From(int? status, string? providerCode, string? detail)
    {
        ProviderStatus = status;
        ProviderCode = providerCode;
        Detail = detail;
        return this;
    }

    public static AiException NotConfigured() =>
        new(StatusCodes.Status503ServiceUnavailable, "ai_not_configured", "AI analysis is not connected on this server.");
    public static AiException Unavailable(string message = "The AI service is unavailable. Try again later.") =>
        new(StatusCodes.Status503ServiceUnavailable, "ai_unavailable", message);
    public static AiException Rejected() =>
        Unavailable("The AI service rejected the request. The administrator has been notified in the logs.");
    public static AiException RateLimited() =>
        new(StatusCodes.Status429TooManyRequests, "ai_rate_limited", "The AI service is busy. Try again in a minute.");
    public static AiException InvalidResponse(string message, AiUsage? usage = null, string? model = null) =>
        new(StatusCodes.Status502BadGateway, "ai_invalid_response", message, usage, model);
    public static AiException Refused(AiUsage? usage = null, string? model = null) =>
        new(StatusCodes.Status422UnprocessableEntity, "ai_refused", "The AI service declined to analyse this request.", usage, model);
}
