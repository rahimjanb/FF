using System.Text.Json;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>
/// AI settings (section "Ai"). The API key is a secret: environment variable <c>Ai__ApiKey</c> or user-secrets,
/// never appsettings or source code. Provider "None" (the default) switches every AI feature off: the app shows that
/// photo analysis is not connected, the diary, barcodes and manual search keep working.
/// </summary>
public sealed class AiOptions
{
    public const string Section = "Ai";

    /// <summary>"Anthropic" (Claude) or "None".</summary>
    public string Provider { get; set; } = "None";
    public string? ApiKey { get; set; }
    /// <summary>Optional gateway/proxy URL in front of the provider's API.</summary>
    public string? BaseUrl { get; set; }
    /// <summary>Model for food photos and labels (vision + structured JSON).</summary>
    public string VisionModel { get; set; } = "claude-opus-5-5";
    /// <summary>Model for the nutrition consultant and the reports.</summary>
    public string ChatModel { get; set; } = "claude-opus-5-5";
    /// <summary>Reasoning effort: low, medium, high, xhigh, max. Lower is faster and cheaper.</summary>
    public string VisionEffort { get; set; } = "medium";
    public string ChatEffort { get; set; } = "medium";
    public int TimeoutSeconds { get; set; } = 90;
    /// <summary>Retries of one request on 408/409/429/5xx and network errors (with backoff, by the SDK).</summary>
    public int MaxRetries { get; set; } = 2;
    public int VisionMaxTokens { get; set; } = 16000;
    public int ChatMaxTokens { get; set; } = 16000;
    /// <summary>If the model declines a request for policy reasons, the provider retries it on its default substitute model.</summary>
    public bool RefusalFallback { get; set; } = true;

    /// <summary>Per client per club-local day. 0 = no limit.</summary>
    public int PhotoScansPerDay { get; set; } = 30;
    public int LabelScansPerDay { get; set; } = 30;
    public int ChatMessagesPerDay { get; set; } = 60;
    public int ReportsPerDay { get; set; } = 10;
    /// <summary>Spending cap for all clients in a calendar month, USD. 0 = no cap.</summary>
    public decimal MonthlyBudgetUsd { get; set; } = 100;

    /// <summary>USD per million tokens, by model id. Configurable, so a price change needs no new release.</summary>
    public Dictionary<string, AiModelPrice> Prices { get; set; } = new()
    {
        ["claude-opus-5-5"] = new() { InputPerMTok = 4m, OutputPerMTok = 20m, CacheReadPerMTok = 0.20m, CacheWritePerMTok = 5m },
        ["claude-sonnet-5-5"] = new() { InputPerMTok = 2m, OutputPerMTok = 10m, CacheReadPerMTok = 0.20m, CacheWritePerMTok = 2.5m },
        ["claude-haiku-5-5"] = new() { InputPerMTok = 0.10m, OutputPerMTok = 0.50m, CacheReadPerMTok = 0.01m, CacheWritePerMTok = 0.125m },
    };

    public bool IsEnabled => !string.Equals(Provider, "None", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(ApiKey);
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
    AiFeature Feature, string Model, string Effort, string System, string UserText, IReadOnlyList<AiImage> Images,
    JsonObject Schema, int MaxTokens);

public record AiJsonResponse(string Json, string Model, AiUsage Usage, TimeSpan Duration)
{
    /// <summary>The AiUsage row recorded for this request (set by <see cref="AiGateway"/>).</summary>
    public Guid? UsageId { get; init; }
}

public record AiToolDefinition(string Name, string Description, JsonObject InputSchema);

public record AiToolCall(string Name, JsonElement Input);

public record AiChatMessage(string Role, string Text);

public record AiChatRequest(
    AiFeature Feature, string Model, string Effort, string System, IReadOnlyList<AiChatMessage> Messages,
    IReadOnlyList<AiToolDefinition> Tools, int MaxTokens, int MaxToolRounds);

public record AiChatResponse(string Text, string Model, AiUsage Usage, TimeSpan Duration, IReadOnlyList<string> ToolsUsed);

/// <summary>
/// The AI provider seen by the business logic. Implementations: <see cref="AnthropicAiClient"/> (Claude) and
/// <see cref="DisabledAiClient"/>; tests use a fake. Business code never references a provider SDK.
/// </summary>
public interface IAiModelClient
{
    /// <summary>Provider name shown to the client in the consent text, e.g. "Anthropic (Claude)".</summary>
    string DisplayName { get; }
    string ProviderId { get; }
    bool IsConfigured { get; }

    Task<AiJsonResponse> GenerateJsonAsync(AiJsonRequest request, CancellationToken ct);

    /// <summary>A conversation in which the model may call <see cref="AiChatRequest.Tools"/>; <paramref name="runTool"/> answers them.</summary>
    Task<AiChatResponse> ChatAsync(AiChatRequest request, Func<AiToolCall, CancellationToken, Task<string>> runTool, CancellationToken ct);
}

/// <summary>
/// AI failure with a stable code for the app. Usage carries the tokens already spent (so they are still counted).
/// </summary>
public sealed class AiException(int statusCode, string code, string message, AiUsage? usage = null, string? model = null)
    : ApiException(statusCode, code, message)
{
    public AiUsage Usage { get; } = usage ?? AiUsage.None;
    public string? Model { get; } = model;

    public static AiException NotConfigured() =>
        new(StatusCodes.Status503ServiceUnavailable, "ai_not_configured", "AI analysis is not connected on this server.");
    public static AiException Unavailable(string message = "The AI service is unavailable. Try again later.") =>
        new(StatusCodes.Status503ServiceUnavailable, "ai_unavailable", message);
    public static AiException RateLimited() =>
        new(StatusCodes.Status429TooManyRequests, "ai_rate_limited", "The AI service is busy. Try again in a minute.");
    public static AiException InvalidResponse(string message, AiUsage? usage = null, string? model = null) =>
        new(StatusCodes.Status502BadGateway, "ai_invalid_response", message, usage, model);
    public static AiException Refused(AiUsage? usage = null, string? model = null) =>
        new(StatusCodes.Status422UnprocessableEntity, "ai_refused", "The AI service declined to analyse this request.", usage, model);
}
