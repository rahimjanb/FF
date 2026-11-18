using System.Diagnostics;
using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>
/// ChatGPT models through the OpenAI Responses API (<c>POST /v1/responses</c>): images, Structured Outputs (the JSON
/// is constrained to the schema; the business layer still validates it) and function tools work there for every
/// current model, while Chat Completions limits tools on the newest ones. Requests are stateless (<c>store: false</c>):
/// nothing is kept on OpenAI's side for later turns; reasoning between tool calls is passed back encrypted.
/// 408/409/429/5xx and network errors are retried with backoff (<see cref="AiClientSettings.MaxRetries"/>), each
/// attempt limited to <see cref="AiClientSettings.TimeoutSeconds"/>. Billing errors (no credit, spend limit) are not
/// retried: retrying cannot help.
/// </summary>
public sealed partial class OpenAiClient : IAiModelClient
{
    public const string HttpClientName = "openai";
    public const string DefaultBaseUrl = "https://api.openai.com/v1";

    private readonly AiClientSettings _settings;
    private readonly IHttpClientFactory _http;
    private readonly ILogger<OpenAiClient> _logger;
    private readonly Uri _endpoint;

    public OpenAiClient(AiClientSettings settings, IHttpClientFactory http, ILogger<OpenAiClient> logger)
    {
        _settings = settings;
        _http = http;
        _logger = logger;
        // Accepts both "https://host" and "https://host/v1" (how OpenAI-compatible gateways are usually written).
        var root = (string.IsNullOrWhiteSpace(settings.BaseUrl) ? DefaultBaseUrl : settings.BaseUrl).Trim().TrimEnd('/');
        if (!root.EndsWith("/v1", StringComparison.OrdinalIgnoreCase)) root += "/v1";
        _endpoint = new Uri(root + "/responses");
    }

    public string DisplayName => "OpenAI (ChatGPT)";
    public string ProviderId => AiProviders.OpenAI;
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_settings.ApiKey);

    public async Task<AiJsonResponse> GenerateJsonAsync(AiJsonRequest request, CancellationToken ct)
    {
        if (!IsConfigured) throw AiException.NotConfigured();
        var content = new JsonArray();
        foreach (var image in request.Images)
            content.Add(new JsonObject
            {
                ["type"] = "input_image",
                ["image_url"] = $"data:{image.MediaType};base64,{Convert.ToBase64String(image.Data)}",
                ["detail"] = "high",
            });
        content.Add(new JsonObject { ["type"] = "input_text", ["text"] = request.UserText });

        var body = Body(request.Model, request.Effort, request.MaxTokens);
        // The instructions come first and are identical across requests, so OpenAI's automatic prompt caching applies.
        body["input"] = new JsonArray(Developer(request.System), new JsonObject { ["role"] = "user", ["content"] = content });
        body["text"] = new JsonObject
        {
            ["format"] = new JsonObject
            {
                ["type"] = "json_schema",
                ["name"] = request.Feature.ToString(),
                ["schema"] = request.Schema.DeepClone(),
                ["strict"] = true,
            },
        };

        var watch = Stopwatch.StartNew();
        var response = await SendAsync(body, ct);
        var usage = UsageOf(response);
        var model = ModelOf(response, request.Model);
        CheckStatus(response, usage, model);
        var (text, refused) = TextOf(response);
        if (refused) throw AiException.Refused(usage, model);
        if (string.IsNullOrWhiteSpace(text)) throw AiException.InvalidResponse("The AI answer has no content.", usage, model);
        return new AiJsonResponse(text, model, usage, watch.Elapsed);
    }

    public async Task<AiChatResponse> ChatAsync(AiChatRequest request, Func<AiToolCall, CancellationToken, Task<string>> runTool,
        CancellationToken ct)
    {
        if (!IsConfigured) throw AiException.NotConfigured();
        var input = new JsonArray { Developer(request.System) };
        foreach (var m in request.Messages)
            input.Add(new JsonObject { ["role"] = m.Role == "assistant" ? "assistant" : "user", ["content"] = m.Text });
        var tools = new JsonArray(request.Tools.Select(t => (JsonNode)new JsonObject
        {
            ["type"] = "function",
            ["name"] = t.Name,
            ["description"] = t.Description,
            ["parameters"] = t.InputSchema.DeepClone(),
            // The tool schemas have optional arguments; the tools validate their input themselves.
            ["strict"] = false,
        }).ToArray());

        var watch = Stopwatch.StartNew();
        var usage = AiUsage.None;
        var used = new List<string>();
        var model = request.Model;
        for (var round = 0; ; round++)
        {
            var body = Body(request.Model, request.Effort, request.MaxTokens);
            body["input"] = input.DeepClone();
            if (tools.Count > 0)
            {
                body["tools"] = tools.DeepClone();
                // Stateless tool loop: the model's reasoning goes back encrypted with the tool results.
                if (SupportsReasoning(request.Model)) body["include"] = new JsonArray("reasoning.encrypted_content");
            }
            var response = await SendAsync(body, ct);
            usage = usage.Add(UsageOf(response));
            model = ModelOf(response, model);
            CheckStatus(response, usage, model);

            var output = response["output"] as JsonArray ?? [];
            var calls = output.OfType<JsonObject>().Where(i => Str(i, "type") == "function_call").ToList();
            if (calls.Count == 0)
            {
                var (text, refused) = TextOf(response);
                if (refused) throw AiException.Refused(usage, model);
                text = text.Trim();
                if (text.Length == 0) throw AiException.InvalidResponse("The AI answer has no text.", usage, model);
                return new AiChatResponse(text, model, usage, watch.Elapsed, used.Distinct().ToList());
            }
            if (round >= request.MaxToolRounds)
                throw AiException.InvalidResponse("The AI made too many data requests for one answer.", usage, model);

            // The turn goes back in its original order: reasoning items unchanged (with their encrypted content),
            // the text as an assistant message, the calls by call_id.
            foreach (var item in output.OfType<JsonObject>())
            {
                switch (Str(item, "type"))
                {
                    case "reasoning":
                        input.Add(item.DeepClone());
                        break;
                    case "message":
                        var said = MessageText(item);
                        if (said.Length > 0) input.Add(new JsonObject { ["role"] = "assistant", ["content"] = said });
                        break;
                    case "function_call":
                        input.Add(new JsonObject
                        {
                            ["type"] = "function_call",
                            ["call_id"] = Str(item, "call_id"),
                            ["name"] = Str(item, "name"),
                            ["arguments"] = Str(item, "arguments") ?? "{}",
                        });
                        break;
                }
            }
            foreach (var call in calls)
            {
                var name = Str(call, "name") ?? "";
                used.Add(name);
                string result;
                try
                {
                    using var args = JsonDocument.Parse(Str(call, "arguments") is { Length: > 0 } a ? a : "{}");
                    result = await runTool(new AiToolCall(name, args.RootElement.Clone()), ct);
                }
                catch (Exception e) when (e is not OperationCanceledException)
                {
                    _logger.LogWarning(e, "AI tool {Tool} failed", name);
                    result = "{\"error\":\"The data could not be loaded.\"}";
                }
                input.Add(new JsonObject { ["type"] = "function_call_output", ["call_id"] = Str(call, "call_id"), ["output"] = result });
            }
        }
    }

    private static JsonObject Developer(string system) => new() { ["role"] = "developer", ["content"] = system };

    private static JsonObject Body(string model, string effort, int maxTokens)
    {
        var body = new JsonObject
        {
            ["model"] = model,
            // Visible answer and reasoning together.
            ["max_output_tokens"] = maxTokens,
            // Nothing is stored at OpenAI for later turns (privacy); every request carries what it needs.
            ["store"] = false,
        };
        if (SupportsReasoning(model) && !string.IsNullOrWhiteSpace(effort))
            body["reasoning"] = new JsonObject { ["effort"] = effort };
        return body;
    }

    /// <summary>GPT-5 and later and the o-series accept a reasoning effort; older models (gpt-4o, gpt-4.1) reject it.</summary>
    public static bool SupportsReasoning(string model) => ReasoningModel().IsMatch(model);

    [GeneratedRegex(@"^(o\d|gpt-([5-9]|[1-9]\d))", RegexOptions.IgnoreCase)]
    private static partial Regex ReasoningModel();

    private async Task<JsonObject> SendAsync(JsonObject body, CancellationToken ct)
    {
        var payload = body.ToJsonString();
        var retries = Math.Clamp(_settings.MaxRetries, 0, 5);
        var seconds = Math.Clamp(_settings.TimeoutSeconds, 10, 600);
        for (var attempt = 0; ; attempt++)
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(TimeSpan.FromSeconds(seconds));
            int status;
            string text;
            TimeSpan? retryAfter;
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, _endpoint)
                {
                    Content = new StringContent(payload, Encoding.UTF8, "application/json"),
                };
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _settings.ApiKey);
                using var response = await _http.CreateClient(HttpClientName).SendAsync(request, timeout.Token);
                status = (int)response.StatusCode;
                text = await response.Content.ReadAsStringAsync(timeout.Token);
                retryAfter = RetryAfter(response);
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                if (attempt < retries) { await DelayAsync(attempt, null, ct); continue; }
                _logger.LogWarning("OpenAI request timed out after {Seconds} s", seconds);
                throw AiException.Unavailable("The AI service did not answer in time. Try again.")
                    .From(null, "timeout", $"OpenAI did not answer within {seconds} s.");
            }
            catch (HttpRequestException e)
            {
                if (attempt < retries) { await DelayAsync(attempt, null, ct); continue; }
                _logger.LogWarning("OpenAI network error: {Message}", e.Message);
                throw AiException.Unavailable().From(null, "network", "OpenAI could not be reached: " + e.Message);
            }

            if (status is >= 200 and < 300)
            {
                try
                {
                    return JsonNode.Parse(text) as JsonObject ?? throw new JsonException("not an object");
                }
                catch (JsonException)
                {
                    throw AiException.InvalidResponse("The AI service sent an unreadable answer.")
                        .From(status, "unreadable", "OpenAI answered with something that is not JSON.");
                }
            }

            var (type, code, message) = ErrorOf(text);
            var billing = IsBillingError(status, type, code);
            var retryable = !billing && status is 408 or 409 or 429 or >= 500;
            if (retryable && attempt < retries)
            {
                await DelayAsync(attempt, retryAfter, ct);
                continue;
            }
            var errorCode = code ?? type;
            var detail = errorCode is null ? $"OpenAI {status}: {message}" : $"OpenAI {status} {errorCode}: {message}";
            if (retryable) _logger.LogWarning("{Detail}", detail);
            else _logger.LogError("{Detail}", detail); // a bad key, no credit, an unknown model: the operator must act
            throw (status == 429 && !billing ? AiException.RateLimited()
                    : status >= 500 || status == 408 ? AiException.Unavailable()
                    : AiException.Rejected())
                .From(status, errorCode, detail);
        }
    }

    /// <summary>No credit, a spend or usage limit: the account needs attention, retrying does not help.</summary>
    public static bool IsBillingError(int status, string? type, string? code) =>
        status == 429 && (type == "insufficient_quota" || code is not null &&
            (code.Contains("quota") || code.Contains("credit") || code.Contains("billing") || code.Contains("spend_limit")
             || code.Contains("usage_limit")));

    private static async Task DelayAsync(int attempt, TimeSpan? retryAfter, CancellationToken ct)
    {
        var backoff = TimeSpan.FromMilliseconds(500 * Math.Pow(2, attempt) + Random.Shared.Next(0, 250));
        var delay = retryAfter is { } r && r > TimeSpan.Zero ? r : backoff;
        await Task.Delay(delay > TimeSpan.FromSeconds(20) ? TimeSpan.FromSeconds(20) : delay, ct);
    }

    private static TimeSpan? RetryAfter(HttpResponseMessage response)
    {
        if (response.Headers.TryGetValues("retry-after-ms", out var ms)
            && double.TryParse(ms.FirstOrDefault(), NumberStyles.Float, CultureInfo.InvariantCulture, out var msValue))
            return TimeSpan.FromMilliseconds(msValue);
        return response.Headers.RetryAfter?.Delta;
    }

    private static (string? Type, string? Code, string Message) ErrorOf(string body)
    {
        try
        {
            if (JsonNode.Parse(body)?["error"] is JsonObject e)
                return (Str(e, "type"), Str(e, "code"), Str(e, "message") ?? "no message");
        }
        catch (JsonException) { }
        return (null, null, body.Length > 300 ? body[..300] : body);
    }

    private static void CheckStatus(JsonObject response, AiUsage usage, string model)
    {
        switch (Str(response, "status"))
        {
            case null or "completed":
                return;
            case "incomplete":
                var reason = Str(response["incomplete_details"] as JsonObject, "reason");
                if (reason == "content_filter") throw AiException.Refused(usage, model);
                throw AiException.InvalidResponse("The AI answer was cut off.", usage, model).From(200, reason, $"OpenAI: incomplete ({reason})");
            default:
                var error = response["error"] as JsonObject;
                throw new AiException(StatusCodes.Status503ServiceUnavailable, "ai_unavailable",
                        "The AI service is unavailable. Try again later.", usage, model)
                    .From(200, Str(error, "code"), $"OpenAI: response {Str(response, "status")}: {Str(error, "message")}");
        }
    }

    /// <summary>All output text of the answer; true when the model refused instead of answering.</summary>
    private static (string Text, bool Refused) TextOf(JsonObject response)
    {
        var text = new StringBuilder();
        var refused = false;
        foreach (var item in (response["output"] as JsonArray ?? []).OfType<JsonObject>().Where(i => Str(i, "type") == "message"))
            foreach (var part in (item["content"] as JsonArray ?? []).OfType<JsonObject>())
            {
                if (Str(part, "type") == "output_text") text.Append(Str(part, "text"));
                else if (Str(part, "type") == "refusal") refused = true;
            }
        return (text.ToString(), refused && text.Length == 0);
    }

    private static string MessageText(JsonObject item) => string.Concat((item["content"] as JsonArray ?? []).OfType<JsonObject>()
        .Where(p => Str(p, "type") == "output_text").Select(p => Str(p, "text"))).Trim();

    /// <summary>input_tokens includes the cached part; it is counted separately at its lower price.</summary>
    private static AiUsage UsageOf(JsonObject response)
    {
        if (response["usage"] is not JsonObject u) return AiUsage.None;
        var input = Int(u["input_tokens"]);
        var cached = Int((u["input_tokens_details"] as JsonObject)?["cached_tokens"]);
        return new AiUsage(Math.Max(0, input - cached), Int(u["output_tokens"]), cached, 0);
    }

    private static string ModelOf(JsonObject response, string requested) => Str(response, "model") is { Length: > 0 } m ? m : requested;

    private static string? Str(JsonObject? o, string name) =>
        o?[name] is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;

    private static int Int(JsonNode? n) => n is JsonValue v && v.TryGetValue<long>(out var l) ? (int)l : 0;
}
