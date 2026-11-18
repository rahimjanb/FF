using System.Collections.Concurrent;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FitnessFormulasi.Api.Tests.Infrastructure;

/// <summary>
/// The OpenAI Responses API as seen by <c>OpenAiClient</c>: answers are scripted (queued, or produced by a handler that
/// sees the request), every request is recorded. No network, no tokens.
/// </summary>
public sealed class FakeOpenAi : HttpMessageHandler
{
    public sealed record Request(string Path, string? Authorization, JsonObject Body);

    public ConcurrentQueue<Request> Requests { get; } = new();
    public ConcurrentQueue<(int Status, string Body, Dictionary<string, string>? Headers)> Responses { get; } = new();
    /// <summary>Used when the queue is empty: the answer for a request.</summary>
    public Func<JsonObject, (int Status, string Body)>? Handler { get; set; }

    public void Enqueue(int status, string body, Dictionary<string, string>? headers = null) => Responses.Enqueue((status, body, headers));

    public void Reset()
    {
        Requests.Clear();
        Responses.Clear();
        Handler = null;
    }

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var body = JsonNode.Parse(await request.Content!.ReadAsStringAsync(ct))!.AsObject();
        Requests.Enqueue(new Request(request.RequestUri!.AbsolutePath, request.Headers.Authorization?.ToString(), body));
        var (status, text, headers) = Responses.TryDequeue(out var next) ? next
            : Handler is { } handler ? Tuple(handler(body)) : (500, Error("server_error", "No scripted answer"), null);
        var response = new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(text, Encoding.UTF8, "application/json") };
        foreach (var (name, value) in headers ?? []) response.Headers.TryAddWithoutValidation(name, value);
        return response;
    }

    private static (int, string, Dictionary<string, string>?) Tuple((int Status, string Body) r) => (r.Status, r.Body, null);

    // The handler instance is shared by HttpClientFactory handler rotations: never disposed by them.
    protected override void Dispose(bool disposing) { }

    // ---- Responses API shapes ---------------------------------------------------------------------------------------

    public static JsonObject Usage(int input = 1500, int cached = 1000, int output = 200) => new()
    {
        ["input_tokens"] = input,
        ["input_tokens_details"] = new JsonObject { ["cached_tokens"] = cached },
        ["output_tokens"] = output,
        ["output_tokens_details"] = new JsonObject { ["reasoning_tokens"] = 50 },
        ["total_tokens"] = input + output,
    };

    public static JsonObject Reasoning(string id = "rs_1") => new()
    {
        ["type"] = "reasoning", ["id"] = id, ["summary"] = new JsonArray(), ["encrypted_content"] = "enc-" + id,
    };

    public static JsonObject Message(string text) => new()
    {
        ["type"] = "message", ["id"] = "msg_1", ["status"] = "completed", ["role"] = "assistant",
        ["content"] = new JsonArray(new JsonObject { ["type"] = "output_text", ["text"] = text, ["annotations"] = new JsonArray() }),
    };

    public static JsonObject Refusal(string text) => new()
    {
        ["type"] = "message", ["id"] = "msg_1", ["status"] = "completed", ["role"] = "assistant",
        ["content"] = new JsonArray(new JsonObject { ["type"] = "refusal", ["refusal"] = text }),
    };

    public static JsonObject Call(string callId, string name, object arguments) => new()
    {
        ["type"] = "function_call", ["id"] = "fc_" + callId, ["call_id"] = callId, ["name"] = name,
        ["arguments"] = JsonSerializer.Serialize(arguments), ["status"] = "completed",
    };

    public static string Response(string model, params JsonObject[] output) => Response(model, "completed", null, Usage(), output);

    public static string Response(string model, string status, string? incompleteReason, JsonObject usage, params JsonObject[] output) =>
        new JsonObject
        {
            ["id"] = "resp_1", ["object"] = "response", ["status"] = status, ["model"] = model,
            ["incomplete_details"] = incompleteReason is null ? null : new JsonObject { ["reason"] = incompleteReason },
            ["output"] = new JsonArray(output.Select(o => (JsonNode)o).ToArray()),
            ["usage"] = usage,
            ["error"] = null,
        }.ToJsonString();

    public static string Error(string code, string message, string type = "invalid_request_error") =>
        new JsonObject { ["error"] = new JsonObject { ["message"] = message, ["type"] = type, ["param"] = null, ["code"] = code } }.ToJsonString();
}
