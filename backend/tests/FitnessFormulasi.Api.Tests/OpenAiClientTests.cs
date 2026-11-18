using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Tests;

/// <summary>
/// The ChatGPT client against a stand-in for the OpenAI Responses API: the exact request it sends (image, strict JSON
/// schema, stateless storage, reasoning effort, tools) and how it reads answers, refusals, cut-offs and errors.
/// </summary>
public sealed class OpenAiClientTests
{
    private readonly FakeOpenAi _api = new();

    private sealed class Factory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private OpenAiClient Client(string? baseUrl = null, int retries = 0) =>
        new(new AiClientSettings("sk-test-key-0123456789", baseUrl, 15, retries, true), new Factory(_api), NullLogger<OpenAiClient>.Instance);

    private static AiJsonRequest JsonRequest(string model = "gpt-6.1-terra") => new(AiFeature.FoodPhoto, "SYSTEM PROMPT", "Describe the food.",
        [new AiImage([0xFF, 0xD8, 0xFF, 0xD9], "image/jpeg")],
        new JsonObject
        {
            ["type"] = "object", ["additionalProperties"] = false, ["required"] = new JsonArray("a"),
            ["properties"] = new JsonObject { ["a"] = new JsonObject { ["anyOf"] = new JsonArray(new JsonObject { ["type"] = "number" }, new JsonObject { ["type"] = "null" }) } },
        }, 16000)
    {
        Model = model, Effort = "medium",
    };

    private static readonly Dictionary<string, string> FastRetry = new() { ["retry-after-ms"] = "1" };

    [Fact]
    public async Task Vision_request_has_the_image_the_strict_schema_and_is_not_stored()
    {
        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.1-terra-2026-10-26", FakeOpenAi.Reasoning(), FakeOpenAi.Message("{\"a\":1}")));
        var response = await Client().GenerateJsonAsync(JsonRequest(), default);

        Assert.Equal("{\"a\":1}", response.Json);
        Assert.Equal("gpt-6.1-terra-2026-10-26", response.Model);
        Assert.Equal(new AiUsage(500, 200, 1000, 0), response.Usage); // the cached part of the input is counted apart

        var request = Assert.Single(_api.Requests);
        Assert.Equal("/v1/responses", request.Path);
        Assert.Equal("Bearer sk-test-key-0123456789", request.Authorization);
        var body = request.Body;
        Assert.Equal("gpt-6.1-terra", body["model"]!.GetValue<string>());
        Assert.False(body["store"]!.GetValue<bool>());
        Assert.Equal(16000, body["max_output_tokens"]!.GetValue<int>());
        Assert.Equal("medium", body["reasoning"]!["effort"]!.GetValue<string>());
        Assert.Null(body["temperature"]);
        var input = body["input"]!.AsArray();
        Assert.Equal(("developer", "SYSTEM PROMPT"), (input[0]!["role"]!.GetValue<string>(), input[0]!["content"]!.GetValue<string>()));
        var content = input[1]!["content"]!.AsArray();
        Assert.Equal("user", input[1]!["role"]!.GetValue<string>());
        Assert.Equal(("input_image", "data:image/jpeg;base64,/9j/2Q==", "high"), (content[0]!["type"]!.GetValue<string>(),
            content[0]!["image_url"]!.GetValue<string>(), content[0]!["detail"]!.GetValue<string>()));
        Assert.Equal(("input_text", "Describe the food."), (content[1]!["type"]!.GetValue<string>(), content[1]!["text"]!.GetValue<string>()));
        var format = body["text"]!["format"]!;
        Assert.Equal(("json_schema", "FoodPhoto", true), (format["type"]!.GetValue<string>(), format["name"]!.GetValue<string>(),
            format["strict"]!.GetValue<bool>()));
        Assert.False(format["schema"]!["additionalProperties"]!.GetValue<bool>());
        Assert.Equal("null", format["schema"]!["properties"]!["a"]!["anyOf"]![1]!["type"]!.GetValue<string>());
    }

    [Theory]
    [InlineData(null, "/v1/responses")]
    [InlineData("https://gateway.example/v1/", "/v1/responses")]
    [InlineData("https://gateway.example", "/v1/responses")]
    [InlineData("https://gateway.example/openai/v1", "/openai/v1/responses")]
    public async Task Base_url_with_or_without_v1_reaches_the_responses_endpoint(string? baseUrl, string path)
    {
        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.1-terra", FakeOpenAi.Message("{}")));
        await Client(baseUrl).GenerateJsonAsync(JsonRequest(), default);
        Assert.Equal(path, Assert.Single(_api.Requests).Path);
    }

    [Theory]
    [InlineData("gpt-6.2-sol", true)]
    [InlineData("gpt-6-luna", true)]
    [InlineData("gpt-5.1", true)]
    [InlineData("o4-mini", true)]
    [InlineData("gpt-4.1", false)]
    [InlineData("gpt-4o", false)]
    public async Task Reasoning_effort_is_sent_only_to_models_that_accept_it(string model, bool sent)
    {
        _api.Enqueue(200, FakeOpenAi.Response(model, FakeOpenAi.Message("{}")));
        await Client().GenerateJsonAsync(JsonRequest(model), default);
        Assert.Equal(sent, Assert.Single(_api.Requests).Body["reasoning"] is not null);
    }

    [Fact]
    public async Task A_refusal_and_a_content_filter_stop_become_ai_refused_with_the_tokens_spent()
    {
        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.1-terra", FakeOpenAi.Refusal("I can't help with that.")));
        var e = await Assert.ThrowsAsync<AiException>(() => Client().GenerateJsonAsync(JsonRequest(), default));
        Assert.Equal(("ai_refused", 500), (e.Code, e.Usage.InputTokens));

        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.1-terra", "incomplete", "content_filter", FakeOpenAi.Usage()));
        Assert.Equal("ai_refused", (await Assert.ThrowsAsync<AiException>(() => Client().GenerateJsonAsync(JsonRequest(), default))).Code);
    }

    [Fact]
    public async Task A_cut_off_answer_is_an_invalid_response_that_still_counts_its_tokens()
    {
        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.1-terra", "incomplete", "max_output_tokens", FakeOpenAi.Usage(output: 16000),
            FakeOpenAi.Message("{\"a\":")));
        var e = await Assert.ThrowsAsync<AiException>(() => Client().GenerateJsonAsync(JsonRequest(), default));
        Assert.Equal(("ai_invalid_response", 16000), (e.Code, e.Usage.OutputTokens));
    }

    [Theory]
    [InlineData(401, "invalid_api_key", "invalid_request_error", "ai_unavailable", 1)]
    [InlineData(404, "model_not_found", "invalid_request_error", "ai_unavailable", 1)]
    [InlineData(400, "invalid_json_schema", "invalid_request_error", "ai_unavailable", 1)]
    [InlineData(429, "credit_balance_exhausted", "insufficient_quota", "ai_unavailable", 1)] // retrying cannot add credit
    [InlineData(429, "project_spend_limit_exceeded", "insufficient_quota", "ai_unavailable", 1)]
    [InlineData(429, "rate_limit_exceeded", "rate_limit_error", "ai_rate_limited", 2)]
    [InlineData(500, "server_error", "server_error", "ai_unavailable", 2)]
    public async Task Provider_errors_map_to_codes_the_app_understands_and_only_transient_ones_are_retried(
        int status, string code, string type, string expected, int requests)
    {
        for (var i = 0; i < 2; i++) _api.Enqueue(status, FakeOpenAi.Error(code, "test message", type), FastRetry);
        var e = await Assert.ThrowsAsync<AiException>(() => Client(retries: 1).GenerateJsonAsync(JsonRequest(), default));
        Assert.Equal(expected, e.Code);
        Assert.Equal(status, e.ProviderStatus);
        Assert.Equal(code, e.ProviderCode);
        Assert.Contains("test message", e.Detail);
        Assert.Equal(requests, _api.Requests.Count);
        Assert.Equal(status == 429 && type == "insufficient_quota", OpenAiClient.IsBillingError(status, type, code));
        Assert.Equal(status == 429 && type == "insufficient_quota", OpenAiClient.IsBillingError(status, null, code)); // by the code alone
    }

    [Fact]
    public async Task A_transient_error_is_retried_and_the_retry_succeeds()
    {
        _api.Enqueue(503, FakeOpenAi.Error("server_error", "overloaded", "server_error"), FastRetry);
        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.1-terra", FakeOpenAi.Message("{\"a\":2}")));
        Assert.Equal("{\"a\":2}", (await Client(retries: 2).GenerateJsonAsync(JsonRequest(), default)).Json);
        Assert.Equal(2, _api.Requests.Count);
    }

    [Fact]
    public async Task Consultant_runs_tools_statelessly_passing_the_encrypted_reasoning_back()
    {
        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.2-sol-2026-11-03", FakeOpenAi.Reasoning("rs_a"), FakeOpenAi.Message("Смотрю дневник."),
            FakeOpenAi.Call("call_1", "get_diary_day", new { date = "2026-11-18" })));
        _api.Enqueue(200, FakeOpenAi.Response("gpt-6.2-sol-2026-11-03", FakeOpenAi.Message("Сегодня 390 ккал.")));
        var calls = new List<AiToolCall>();
        var reply = await Client().ChatAsync(new AiChatRequest(AiFeature.Consultant, "SYSTEM",
            [new AiChatMessage("user", "Привет"), new AiChatMessage("assistant", "Здравствуйте!"), new AiChatMessage("user", "Сколько калорий?")],
            [new AiToolDefinition("get_diary_day", "Diary", new JsonObject
            {
                ["type"] = "object", ["properties"] = new JsonObject { ["date"] = new JsonObject { ["type"] = "string" } }, ["required"] = new JsonArray("date"),
            })], 16000, 6) { Model = "gpt-6.2-sol", Effort = "low" },
            (call, _) =>
            {
                calls.Add(call);
                return Task.FromResult("{\"kcal\":390}");
            }, default);

        Assert.Equal("Сегодня 390 ккал.", reply.Text);
        Assert.Equal(["get_diary_day"], reply.ToolsUsed);
        Assert.Equal(new AiUsage(1000, 400, 2000, 0), reply.Usage);
        Assert.Equal("2026-11-18", Assert.Single(calls).Input.GetProperty("date").GetString());

        var requests = _api.Requests.ToArray();
        Assert.Equal(2, requests.Length);
        var first = requests[0].Body;
        Assert.Equal(("function", "get_diary_day", false), (first["tools"]![0]!["type"]!.GetValue<string>(),
            first["tools"]![0]!["name"]!.GetValue<string>(), first["tools"]![0]!["strict"]!.GetValue<bool>()));
        Assert.Equal("string", first["tools"]![0]!["parameters"]!["properties"]!["date"]!["type"]!.GetValue<string>());
        Assert.Equal("reasoning.encrypted_content", first["include"]![0]!.GetValue<string>());
        Assert.Equal("low", first["reasoning"]!["effort"]!.GetValue<string>());
        Assert.Equal(["developer", "user", "assistant", "user"], first["input"]!.AsArray().Select(i => i!["role"]!.GetValue<string>()));

        // Second request: the whole history, then the model's turn in order, then the tool result.
        var input = requests[1].Body["input"]!.AsArray();
        Assert.Equal(8, input.Count);
        Assert.Equal(("reasoning", "rs_a", "enc-rs_a"), (input[4]!["type"]!.GetValue<string>(), input[4]!["id"]!.GetValue<string>(),
            input[4]!["encrypted_content"]!.GetValue<string>()));
        Assert.Equal(("assistant", "Смотрю дневник."), (input[5]!["role"]!.GetValue<string>(), input[5]!["content"]!.GetValue<string>()));
        Assert.Equal(("function_call", "call_1", "get_diary_day"), (input[6]!["type"]!.GetValue<string>(),
            input[6]!["call_id"]!.GetValue<string>(), input[6]!["name"]!.GetValue<string>()));
        Assert.Equal(("function_call_output", "call_1", "{\"kcal\":390}"), (input[7]!["type"]!.GetValue<string>(),
            input[7]!["call_id"]!.GetValue<string>(), input[7]!["output"]!.GetValue<string>()));
    }

    [Fact]
    public async Task Too_many_tool_rounds_end_with_an_error()
    {
        _api.Handler = _ => (200, FakeOpenAi.Response("gpt-6.2-sol", FakeOpenAi.Call(Guid.NewGuid().ToString("N"), "get_diary_day", new { date = "2026-11-18" })));
        var e = await Assert.ThrowsAsync<AiException>(() => Client().ChatAsync(new AiChatRequest(AiFeature.Consultant, "SYSTEM",
            [new AiChatMessage("user", "?")], [new AiToolDefinition("get_diary_day", "Diary", new JsonObject { ["type"] = "object" })], 1000, 2)
        {
            Model = "gpt-6.2-sol", Effort = "low",
        }, (_, _) => Task.FromResult("{}"), default));
        Assert.Equal("ai_invalid_response", e.Code);
        Assert.Equal(3, _api.Requests.Count);
    }

    [Fact]
    public void Dated_snapshots_are_priced_as_their_model()
    {
        var gateway = new AiGateway(null!, null!, null!, Options.Create(new AiOptions()), null!, NullLogger<AiGateway>.Instance);
        var usage = new AiUsage(1_000_000, 1_000_000, 1_000_000, 0);
        Assert.Equal(1m + 5m + 0.05m, gateway.CostOf("gpt-6.1-terra-2026-10-26", usage));
        Assert.Equal(gateway.CostOf("gpt-6.2-sol", usage), gateway.CostOf("gpt-6.2-sol-2026-11-03", usage));
        Assert.Equal(0m, gateway.CostOf("unknown-model", usage));
    }

    [Fact]
    public void Without_a_key_the_client_is_off()
    {
        var off = new OpenAiClient(new AiClientSettings("", null, 15, 0, true), new Factory(_api), NullLogger<OpenAiClient>.Instance);
        Assert.False(off.IsConfigured);
    }
}
