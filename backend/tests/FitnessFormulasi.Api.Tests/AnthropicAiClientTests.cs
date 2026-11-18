using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Tests;

/// <summary>
/// The real Claude client against a local stand-in for the Messages API: checks the exact request it sends
/// (image, schema, prompt caching, refusal fallback) and how it reads answers and errors. No tokens are spent.
/// </summary>
public sealed class AnthropicAiClientTests : IDisposable
{
    private readonly HttpListener _listener = new();
    private readonly string _baseUrl;
    private readonly Queue<(int Status, string Body)> _responses = new();
    public List<(JsonObject Body, WebHeaderCollection Headers, string Path)> Requests { get; } = [];

    public AnthropicAiClientTests()
    {
        var port = FreePort();
        _baseUrl = $"http://127.0.0.1:{port}";
        _listener.Prefixes.Add(_baseUrl + "/");
        _listener.Start();
        _ = ServeAsync();
    }

    private static int FreePort()
    {
        var l = new TcpListener(IPAddress.Loopback, 0);
        l.Start();
        var port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    private async Task ServeAsync()
    {
        while (_listener.IsListening)
        {
            HttpListenerContext ctx;
            try { ctx = await _listener.GetContextAsync(); }
            catch { return; }
            using var reader = new StreamReader(ctx.Request.InputStream);
            var body = await reader.ReadToEndAsync();
            var headers = new WebHeaderCollection();
            foreach (string name in ctx.Request.Headers) headers[name] = ctx.Request.Headers[name];
            lock (Requests) Requests.Add((JsonNode.Parse(body)!.AsObject(), headers, ctx.Request.Url!.AbsolutePath));
            var (status, response) = _responses.Count > 0 ? _responses.Dequeue() : (500, "{}");
            ctx.Response.StatusCode = status;
            ctx.Response.ContentType = "application/json";
            ctx.Response.Headers["request-id"] = "req_test";
            var bytes = Encoding.UTF8.GetBytes(response);
            await ctx.Response.OutputStream.WriteAsync(bytes);
            ctx.Response.Close();
        }
    }

    public void Dispose() => _listener.Close();

    private AnthropicAiClient Client(bool fallback = true) => new(Options.Create(new AiOptions
    {
        Provider = "Anthropic", ApiKey = "test-key", BaseUrl = _baseUrl, MaxRetries = 0, TimeoutSeconds = 15, RefusalFallback = fallback,
    }), NullLogger<AnthropicAiClient>.Instance);

    private static string Message(string stop, params object[] content) => JsonSerializer.Serialize(new
    {
        id = "msg_test", type = "message", role = "assistant", model = "claude-opus-5-5", content, stop_reason = stop,
        stop_sequence = (string?)null,
        usage = new { input_tokens = 1500, output_tokens = 200, cache_read_input_tokens = 1000, cache_creation_input_tokens = 50 },
    });

    private static readonly object Thinking = new { type = "thinking", thinking = "", signature = "sig-1" };
    private static object Text(string text) => new { type = "text", text };

    private static AiJsonRequest JsonRequest() => new(AiFeature.FoodPhoto, "claude-opus-5-5", "medium", "SYSTEM PROMPT", "Describe the food.",
        [new AiImage([0xFF, 0xD8, 0xFF, 0xD9], "image/jpeg")],
        new JsonObject { ["type"] = "object", ["additionalProperties"] = false, ["required"] = new JsonArray("a"),
            ["properties"] = new JsonObject { ["a"] = new JsonObject { ["type"] = "number" } } }, 16000);

    [Fact]
    public async Task Vision_request_has_the_image_the_schema_cached_instructions_and_the_refusal_fallback()
    {
        _responses.Enqueue((200, Message("end_turn", Thinking, Text("{\"a\":1}"))));
        var response = await Client().GenerateJsonAsync(JsonRequest(), default);

        Assert.Equal("{\"a\":1}", response.Json);
        Assert.Equal("claude-opus-5-5", response.Model);
        Assert.Equal(new AiUsage(1500, 200, 1000, 50), response.Usage);

        var (body, headers, path) = Assert.Single(Requests);
        Assert.Equal("/v1/messages", path);
        Assert.Equal("Bearer test-key", headers["Authorization"]); // SDK 13: the API key goes as a bearer credential
        Assert.Contains("server-side-fallback-2026-07-01", headers["anthropic-beta"]);
        Assert.Equal("claude-opus-5-5", body["model"]!.GetValue<string>());
        Assert.Equal(16000, body["max_tokens"]!.GetValue<int>());
        Assert.Equal("default", body["fallbacks"]!.GetValue<string>());
        Assert.Null(body["thinking"]); // Opus 5.5 thinks adaptively; effort controls the depth
        var system = body["system"]!.AsArray()[0]!;
        Assert.Equal(("SYSTEM PROMPT", "ephemeral"), (system["text"]!.GetValue<string>(), system["cache_control"]!["type"]!.GetValue<string>()));
        var content = body["messages"]!.AsArray()[0]!["content"]!.AsArray();
        Assert.Equal("user", body["messages"]![0]!["role"]!.GetValue<string>());
        Assert.Equal(("image", "base64", "image/jpeg", "/9j/2Q=="), (content[0]!["type"]!.GetValue<string>(),
            content[0]!["source"]!["type"]!.GetValue<string>(), content[0]!["source"]!["media_type"]!.GetValue<string>(),
            content[0]!["source"]!["data"]!.GetValue<string>()));
        Assert.Equal("Describe the food.", content[1]!["text"]!.GetValue<string>());
        var output = body["output_config"]!;
        Assert.Equal("medium", output["effort"]!.GetValue<string>());
        Assert.Equal("json_schema", output["format"]!["type"]!.GetValue<string>());
        Assert.False(output["format"]!["schema"]!["additionalProperties"]!.GetValue<bool>());
    }

    [Fact]
    public async Task Without_the_fallback_option_no_beta_is_sent()
    {
        _responses.Enqueue((200, Message("end_turn", Text("{}"))));
        await Client(fallback: false).GenerateJsonAsync(JsonRequest(), default);
        var (body, headers, _) = Assert.Single(Requests);
        Assert.Null(body["fallbacks"]);
        Assert.DoesNotContain("server-side-fallback", headers["anthropic-beta"] ?? "");
    }

    [Theory]
    [InlineData("refusal", "ai_refused")]
    [InlineData("max_tokens", "ai_invalid_response")]
    public async Task Refusals_and_cut_off_answers_become_stable_errors_with_the_tokens_spent(string stop, string code)
    {
        _responses.Enqueue((200, Message(stop, Text("{"))));
        var e = await Assert.ThrowsAsync<AiException>(() => Client().GenerateJsonAsync(JsonRequest(), default));
        Assert.Equal(code, e.Code);
        Assert.Equal(1500, e.Usage.InputTokens); // still counted against the budget
    }

    [Theory]
    [InlineData(429, "rate_limit_error", "ai_rate_limited")]
    [InlineData(529, "overloaded_error", "ai_unavailable")]
    [InlineData(500, "api_error", "ai_unavailable")]
    [InlineData(400, "invalid_request_error", "ai_unavailable")]
    [InlineData(401, "authentication_error", "ai_unavailable")]
    public async Task Provider_errors_map_to_codes_the_app_understands(int status, string type, string code)
    {
        _responses.Enqueue((status, JsonSerializer.Serialize(new { type = "error", error = new { type, message = "test" } })));
        var e = await Assert.ThrowsAsync<AiException>(() => Client().GenerateJsonAsync(JsonRequest(), default));
        Assert.Equal(code, e.Code);
    }

    [Fact]
    public async Task Consultant_runs_tools_and_sends_the_assistant_turn_back_unchanged()
    {
        _responses.Enqueue((200, Message("tool_use", Thinking, Text("Смотрю дневник."),
            new { type = "tool_use", id = "toolu_1", name = "get_diary_day", input = new { date = "2026-11-18" } })));
        _responses.Enqueue((200, Message("end_turn", Text("Сегодня 390 ккал."))));
        var calls = new List<AiToolCall>();
        var reply = await Client().ChatAsync(new AiChatRequest(AiFeature.Consultant, "claude-opus-5-5", "low", "SYSTEM",
            [new AiChatMessage("user", "Сколько калорий?")],
            [new AiToolDefinition("get_diary_day", "Diary", new JsonObject
            {
                ["type"] = "object", ["properties"] = new JsonObject { ["date"] = new JsonObject { ["type"] = "string" } }, ["required"] = new JsonArray("date"),
            })], 16000, 6),
            (call, _) =>
            {
                calls.Add(call);
                return Task.FromResult("{\"kcal\":390}");
            }, default);

        Assert.Equal("Сегодня 390 ккал.", reply.Text);
        Assert.Equal(["get_diary_day"], reply.ToolsUsed);
        Assert.Equal(new AiUsage(3000, 400, 2000, 100), reply.Usage);
        Assert.Equal("2026-11-18", Assert.Single(calls).Input.GetProperty("date").GetString());

        Assert.Equal(2, Requests.Count);
        var first = Requests[0].Body;
        Assert.Equal("get_diary_day", first["tools"]![0]!["name"]!.GetValue<string>());
        Assert.Equal("string", first["tools"]![0]!["input_schema"]!["properties"]!["date"]!["type"]!.GetValue<string>());
        var messages = Requests[1].Body["messages"]!.AsArray();
        Assert.Equal(3, messages.Count);
        var assistant = messages[1]!["content"]!.AsArray();
        Assert.Equal(("thinking", "sig-1"), (assistant[0]!["type"]!.GetValue<string>(), assistant[0]!["signature"]!.GetValue<string>()));
        Assert.Equal("tool_use", assistant[2]!["type"]!.GetValue<string>());
        var result = messages[2]!["content"]![0]!;
        Assert.Equal(("tool_result", "toolu_1", "{\"kcal\":390}"), (result["type"]!.GetValue<string>(),
            result["tool_use_id"]!.GetValue<string>(), result["content"]!.GetValue<string>()));
    }

    [Fact]
    public async Task Without_a_key_the_client_is_off()
    {
        var off = new AnthropicAiClient(Options.Create(new AiOptions { Provider = "Anthropic" }), NullLogger<AnthropicAiClient>.Instance);
        Assert.False(off.IsConfigured);
        Assert.Equal("ai_not_configured", (await Assert.ThrowsAsync<AiException>(() => off.GenerateJsonAsync(JsonRequest(), default))).Code);
    }
}
