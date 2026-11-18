using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Nodes;
using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Beta.Messages;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>
/// Claude through the official Anthropic SDK. Vision answers use structured outputs (the JSON is constrained to the
/// schema; the business layer still validates it). The consultant runs a manual tool loop. The SDK retries
/// 408/409/429/5xx and network errors with backoff (<see cref="AiClientSettings.MaxRetries"/>) within
/// <see cref="AiClientSettings.TimeoutSeconds"/>; a policy refusal is retried by the API on its default substitute model
/// (server-side fallback) when <see cref="AiClientSettings.RefusalFallback"/> is on.
/// </summary>
public sealed class AnthropicAiClient : IAiModelClient
{
    private const string FallbackBeta = "server-side-fallback-2026-07-01";
    private readonly AiClientSettings _settings;
    private readonly ILogger<AnthropicAiClient> _logger;
    private readonly AnthropicClient? _client;

    /// <summary>The provider of the "Ai" configuration section (no key or another provider: not configured).</summary>
    public AnthropicAiClient(IOptions<AiOptions> options, ILogger<AnthropicAiClient> logger)
        : this(AiClientSettings.FromOptions(options.Value, AiProviders.Anthropic), logger) { }

    public AnthropicAiClient(AiClientSettings settings, ILogger<AnthropicAiClient> logger)
    {
        _settings = settings;
        _logger = logger;
        if (string.IsNullOrWhiteSpace(settings.ApiKey)) return;
        var retries = Math.Clamp(settings.MaxRetries, 0, 5);
        var timeout = TimeSpan.FromSeconds(Math.Clamp(settings.TimeoutSeconds, 10, 600));
        _client = string.IsNullOrWhiteSpace(settings.BaseUrl)
            ? new AnthropicClient { ApiKey = settings.ApiKey, MaxRetries = retries, Timeout = timeout }
            : new AnthropicClient { ApiKey = settings.ApiKey, MaxRetries = retries, Timeout = timeout, BaseUrl = settings.BaseUrl };
    }

    public string DisplayName => "Anthropic (Claude)";
    public string ProviderId => AiProviders.Anthropic;
    public bool IsConfigured => _client is not null;

    public async Task<AiJsonResponse> GenerateJsonAsync(AiJsonRequest request, CancellationToken ct)
    {
        var client = _client ?? throw AiException.NotConfigured();
        var content = new List<BetaContentBlockParam>();
        foreach (var image in request.Images)
            content.Add(new BetaImageBlockParam
            {
                Source = new BetaBase64ImageSource { Data = Convert.ToBase64String(image.Data), MediaType = image.MediaType },
            });
        content.Add(new BetaTextBlockParam { Text = request.UserText });

        var parameters = Base(request.Model, request.MaxTokens, request.System) with
        {
            Messages = [new BetaUserMessageParam { Content = content }],
            OutputConfig = new BetaOutputConfig
            {
                Effort = request.Effort,
                Format = new BetaJsonOutputFormat { Schema = ToDictionary(request.Schema) },
            },
        };

        var watch = Stopwatch.StartNew();
        var message = await SendAsync(client, parameters, ct);
        var usage = UsageOf(message);
        CheckStop(message, usage);
        var text = string.Concat(message.Content.Select(b => b.TryPickText(out var t) ? t.Text : ""));
        if (string.IsNullOrWhiteSpace(text))
            throw AiException.InvalidResponse("The AI answer has no content.", usage, message.Model);
        return new AiJsonResponse(text, message.Model, usage, watch.Elapsed);
    }

    public async Task<AiChatResponse> ChatAsync(AiChatRequest request, Func<AiToolCall, CancellationToken, Task<string>> runTool,
        CancellationToken ct)
    {
        var client = _client ?? throw AiException.NotConfigured();
        var tools = request.Tools.Select(t => (BetaToolUnion)new BetaTool
        {
            Name = t.Name,
            Description = t.Description,
            InputSchema = new InputSchema
            {
                Properties = ToDictionary((JsonObject?)t.InputSchema["properties"] ?? []),
                Required = ((JsonArray?)t.InputSchema["required"])?.Select(n => n!.GetValue<string>()).ToList() ?? [],
            },
        }).ToList();

        var messages = new List<BetaMessageParam>();
        foreach (var m in request.Messages)
            messages.Add(m.Role == "assistant"
                ? new BetaAssistantMessageParam { Content = m.Text }
                : new BetaUserMessageParam { Content = m.Text });

        var watch = Stopwatch.StartNew();
        var usage = AiUsage.None;
        var used = new List<string>();
        var model = request.Model;
        for (var round = 0; ; round++)
        {
            var parameters = Base(request.Model, request.MaxTokens, request.System) with
            {
                Messages = messages,
                OutputConfig = new BetaOutputConfig { Effort = request.Effort },
            };
            if (tools.Count > 0) parameters = parameters with { Tools = tools };
            var message = await SendAsync(client, parameters, ct);
            usage = usage.Add(UsageOf(message));
            model = message.Model;
            CheckStop(message, usage);

            var calls = message.Content.Select(b => b.TryPickToolUse(out var tu) ? tu : null).OfType<BetaToolUseBlock>().ToList();
            if (calls.Count == 0 || message.StopReason != "tool_use")
            {
                var text = string.Concat(message.Content.Select(b => b.TryPickText(out var t) ? t.Text : "")).Trim();
                if (text.Length == 0) throw AiException.InvalidResponse("The AI answer has no text.", usage, model);
                return new AiChatResponse(text, model, usage, watch.Elapsed, used.Distinct().ToList());
            }
            if (round >= request.MaxToolRounds)
                throw AiException.InvalidResponse("The AI made too many data requests for one answer.", usage, model);

            // The assistant turn goes back unchanged (thinking blocks included, their signatures intact).
            messages.Add(new BetaAssistantMessageParam { Content = ToParams(message.Content) });
            var results = new List<BetaContentBlockParam>();
            foreach (var call in calls)
            {
                used.Add(call.Name);
                string result;
                var isError = false;
                try
                {
                    var input = JsonSerializer.SerializeToElement(call.Input);
                    result = await runTool(new AiToolCall(call.Name, input), ct);
                }
                catch (Exception e) when (e is not OperationCanceledException)
                {
                    _logger.LogWarning(e, "AI tool {Tool} failed", call.Name);
                    result = "The data could not be loaded.";
                    isError = true;
                }
                results.Add(new BetaToolResultBlockParam { ToolUseID = call.ID, Content = result, IsError = isError });
            }
            messages.Add(new BetaUserMessageParam { Content = results });
        }
    }

    private MessageCreateParams Base(string model, int maxTokens, string system)
    {
        var p = new MessageCreateParams
        {
            Model = model,
            MaxTokens = maxTokens,
            // The instructions and the product catalog are identical across requests: cached, so they cost less.
            System = new List<BetaTextBlockParam> { new() { Text = system, CacheControl = new BetaCacheControlEphemeral() } },
            Messages = [],
        };
        return _settings.RefusalFallback ? p with { Betas = [FallbackBeta], Fallbacks = new Default() } : p;
    }

    private async Task<BetaMessage> SendAsync(AnthropicClient client, MessageCreateParams parameters, CancellationToken ct)
    {
        try
        {
            return await client.Beta.Messages.Create(parameters, ct);
        }
        catch (AnthropicRateLimitException e)
        {
            _logger.LogWarning("Anthropic rate limit: {Message}", e.Message);
            throw AiException.RateLimited().From(429, "rate_limit_error", "Anthropic 429: " + e.Message);
        }
        catch (Anthropic5xxException e)
        {
            _logger.LogWarning("Anthropic server error: {Message}", e.Message);
            throw AiException.Unavailable().From(500, "api_error", "Anthropic server error: " + e.Message);
        }
        catch (AnthropicApiException e)
        {
            // 4xx other than 429: a bad request, an invalid key, an unknown model. Logged for the operator.
            _logger.LogError("Anthropic API error: {Message}", e.Message);
            var status = e switch
            {
                AnthropicUnauthorizedException => 401,
                AnthropicForbiddenException => 403,
                AnthropicNotFoundException => 404,
                AnthropicUnprocessableEntityException => 422,
                _ => 400,
            };
            throw AiException.Rejected().From(status, null, "Anthropic: " + e.Message);
        }
        catch (AnthropicIOException e)
        {
            _logger.LogWarning("Anthropic network error: {Message}", e.Message);
            throw AiException.Unavailable().From(null, "network", "Anthropic could not be reached: " + e.Message);
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            _logger.LogWarning("Anthropic request timed out after {Seconds} s", _settings.TimeoutSeconds);
            throw AiException.Unavailable("The AI service did not answer in time. Try again.")
                .From(null, "timeout", $"Anthropic did not answer within {_settings.TimeoutSeconds} s.");
        }
    }

    private static void CheckStop(BetaMessage message, AiUsage usage)
    {
        if (message.StopReason == "refusal") throw AiException.Refused(usage, message.Model);
        if (message.StopReason == "max_tokens") throw AiException.InvalidResponse("The AI answer was cut off.", usage, message.Model);
    }

    private static AiUsage UsageOf(BetaMessage m) => new(
        (int)m.Usage.InputTokens, (int)m.Usage.OutputTokens,
        (int)(m.Usage.CacheReadInputTokens ?? 0), (int)(m.Usage.CacheCreationInputTokens ?? 0));

    private static List<BetaContentBlockParam> ToParams(IReadOnlyList<BetaContentBlock> blocks)
    {
        var result = new List<BetaContentBlockParam>();
        foreach (var b in blocks)
        {
            if (b.TryPickText(out var text)) result.Add(new BetaTextBlockParam { Text = text.Text });
            else if (b.TryPickThinking(out var thinking))
                result.Add(new BetaThinkingBlockParam { Thinking = thinking.Thinking, Signature = thinking.Signature });
            else if (b.TryPickRedactedThinking(out var redacted)) result.Add(new BetaRedactedThinkingBlockParam { Data = redacted.Data });
            else if (b.TryPickToolUse(out var tu)) result.Add(new BetaToolUseBlockParam { ID = tu.ID, Name = tu.Name, Input = tu.Input });
        }
        return result;
    }

    private static Dictionary<string, JsonElement> ToDictionary(JsonObject schema) =>
        schema.ToDictionary(p => p.Key, p => JsonSerializer.SerializeToElement(p.Value));
}

/// <summary>Used when no AI provider is configured: every AI call answers ai_not_configured.</summary>
public sealed class DisabledAiClient : IAiModelClient
{
    public string DisplayName => "";
    public string ProviderId => "None";
    public bool IsConfigured => false;
    public Task<AiJsonResponse> GenerateJsonAsync(AiJsonRequest request, CancellationToken ct) => throw AiException.NotConfigured();
    public Task<AiChatResponse> ChatAsync(AiChatRequest request, Func<AiToolCall, CancellationToken, Task<string>> runTool,
        CancellationToken ct) => throw AiException.NotConfigured();
}
