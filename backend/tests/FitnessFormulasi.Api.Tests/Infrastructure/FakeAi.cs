using System.Collections.Concurrent;
using System.Text.Json;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using FitnessFormulasi.Api.Features.Nutrition;

namespace FitnessFormulasi.Api.Tests.Infrastructure;

/// <summary>
/// The AI provider of the test run: answers are scripted per test (keyed by a marker the test puts in the photo or
/// the question), no tokens are spent. Every request is recorded so tests can check what would have been sent.
/// </summary>
public sealed class FakeAi : IAiModelClient
{
    public bool Configured { get; set; } = true;
    public string DisplayName => "Fake AI";
    public string ProviderId => "Fake";
    public bool IsConfigured => Configured;

    /// <summary>Answers to JSON requests, by a marker found in the image bytes (a JPEG comment). Several answers are used in turn.</summary>
    public ConcurrentDictionary<string, ConcurrentQueue<Func<string>>> JsonAnswers { get; } = new();
    /// <summary>Chat handlers by a marker in the last user message; they may call tools.</summary>
    public ConcurrentDictionary<string, Func<AiChatRequest, Func<AiToolCall, CancellationToken, Task<string>>, Task<string>>> ChatAnswers { get; } = new();
    public ConcurrentQueue<AiJsonRequest> JsonRequests { get; } = new();
    public ConcurrentQueue<AiChatRequest> ChatRequests { get; } = new();
    /// <summary>When set, a JSON request waits for it (to test concurrent requests).</summary>
    public TaskCompletionSource? Gate { get; set; }

    public static readonly AiUsage Usage = new(1200, 300, 0, 0);

    public void AnswerJson(string marker, params Func<string>[] answers) =>
        JsonAnswers[marker] = new ConcurrentQueue<Func<string>>(answers);

    public int JsonCallsFor(string marker) =>
        JsonRequests.Count(r => r.Images.Any(i => System.Text.Encoding.ASCII.GetString(i.Data).Contains(marker)));

    public async Task<AiJsonResponse> GenerateJsonAsync(AiJsonRequest request, CancellationToken ct)
    {
        if (!Configured) throw AiException.NotConfigured();
        JsonRequests.Enqueue(request);
        if (Gate is { } gate) await gate.Task.WaitAsync(TimeSpan.FromSeconds(10), ct);
        var bytes = request.Images.Count > 0 ? System.Text.Encoding.ASCII.GetString(request.Images[0].Data) : "";
        foreach (var (marker, queue) in JsonAnswers)
        {
            if (!bytes.Contains(marker)) continue;
            if (queue.Count > 1 ? queue.TryDequeue(out var next) : queue.TryPeek(out next))
            {
                var json = next();
                if (json == "unavailable") throw AiException.Unavailable();
                return new AiJsonResponse(json, "fake-model", Usage, TimeSpan.FromMilliseconds(5));
            }
        }
        throw new InvalidOperationException("No scripted AI answer for this image.");
    }

    public async Task<AiChatResponse> ChatAsync(AiChatRequest request, Func<AiToolCall, CancellationToken, Task<string>> runTool,
        CancellationToken ct)
    {
        if (!Configured) throw AiException.NotConfigured();
        ChatRequests.Enqueue(request);
        var last = request.Messages[^1].Text;
        foreach (var (marker, handler) in ChatAnswers)
            if (last.Contains(marker))
            {
                var used = new List<string>();
                var text = await handler(request, async (call, token) =>
                {
                    used.Add(call.Name);
                    return await runTool(call, token);
                });
                return new AiChatResponse(text, "fake-model", Usage, TimeSpan.FromMilliseconds(5), used);
            }
        return new AiChatResponse("ok", "fake-model", Usage, TimeSpan.FromMilliseconds(5), []);
    }

    public static AiToolCall Tool(string name, object input) => new(name, JsonSerializer.SerializeToElement(input));
}

/// <summary>Open Food Facts and USDA stand-ins with scripted products.</summary>
public sealed class FakeFoodSources : IBarcodeProductSource, IFoodSearchSource
{
    public ConcurrentDictionary<string, ExternalProduct> Barcodes { get; } = new();
    public ConcurrentDictionary<string, int> BarcodeCalls { get; } = new();
    public bool BarcodeDown { get; set; }
    public ConcurrentDictionary<string, List<ExternalProduct>> Searches { get; } = new();

    string IBarcodeProductSource.Name => "Fake OFF";
    bool IBarcodeProductSource.IsEnabled => true;
    string IFoodSearchSource.Name => "Fake USDA";
    bool IFoodSearchSource.IsEnabled => true;

    public Task<ExternalProduct?> FindAsync(string barcode, CancellationToken ct)
    {
        BarcodeCalls.AddOrUpdate(barcode, 1, (_, n) => n + 1);
        if (BarcodeDown) throw new FoodSourceUnavailableException("Fake OFF");
        return Task.FromResult(Barcodes.GetValueOrDefault(barcode));
    }

    public Task<IReadOnlyList<ExternalProduct>> SearchAsync(string query, int take, CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<ExternalProduct>>(Searches.GetValueOrDefault(query.ToLowerInvariant()) ?? []);

    public static ExternalProduct Product(string code, string name, decimal kcal, decimal protein, decimal fat, decimal carbs) => new(
        NutritionSource.OpenFoodFacts, code, name, "Brand", FoodCategory.PackagedFood,
        new Per100Values(kcal, protein, fat, carbs, 1, 10, 2, 400), false, 30, 500, [Allergen.Milk], "молоко, сахар");
}
