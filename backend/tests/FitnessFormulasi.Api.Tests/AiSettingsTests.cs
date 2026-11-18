using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using FitnessFormulasi.Api.Features.Nutrition;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static FitnessFormulasi.Api.Tests.NutritionEngineTests;

namespace FitnessFormulasi.Api.Tests;

/// <summary>
/// Connecting ChatGPT from the admin panel: key (encrypted, write-only), connection check with real requests, switching
/// on, a client's photo analysed by OpenAI, consent per provider, the privacy page. The settings are one row shared by
/// the whole run, so everything happens in one test that switches AI back to the server provider at the end.
/// </summary>
[Collection(ApiCollection.Name)]
public class AiSettingsTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static JsonSerializerOptions Json => ApiFactory.Json;
    private FakeOpenAi OpenAi => factory.OpenAi;
    private const string OpenAiKey = "sk-proj-test-key-0123456789-abcd";

    private static async Task<AiSettingsDto> ReadAsync(HttpResponseMessage res)
    {
        Assert.True(res.IsSuccessStatusCode, $"{res.StatusCode}: {await res.Content.ReadAsStringAsync()}");
        return (await res.Content.ReadFromJsonAsync<AiSettingsDto>(Json))!;
    }

    private static Task<HttpResponseMessage> UpdateAsync(HttpClient admin, AiSettingsDto current, bool enabled, string provider = "OpenAI",
        string? vision = null, string? chat = null, decimal? budget = null) =>
        admin.PutAsJsonAsync("/api/admin/ai", new
        {
            isEnabled = enabled, provider, visionModel = vision, chatModel = chat, monthlyBudgetUsd = budget, version = current.Version,
        }, Json);

    /// <summary>Answers like the Responses API: the check picture, the check tool, a dish photo.</summary>
    private static (int, string) Answer(JsonObject body)
    {
        var model = body["model"]!.GetValue<string>();
        var input = body["input"]!.AsArray();
        if (body["tools"] is JsonArray)
            return input.Any(i => i?["type"]?.GetValue<string>() == "function_call_output")
                ? (200, FakeOpenAi.Response(model + "-2026-11-03", FakeOpenAi.Message("4217")))
                : (200, FakeOpenAi.Response(model + "-2026-11-03", FakeOpenAi.Reasoning(), FakeOpenAi.Call("call_1", "get_check_number", new { })));
        var format = body["text"]!["format"]!["name"]!.GetValue<string>();
        return format == "ConnectionCheck"
            ? (200, FakeOpenAi.Response(model + "-2026-10-26", FakeOpenAi.Message("{\"shape\":\"orange\",\"background\":\"green\"}")))
            : (200, FakeOpenAi.Response(model + "-2026-10-26", FakeOpenAi.Message(Vision())));
    }

    private static MultipartFormDataContent Form(byte[] photo)
    {
        var file = new ByteArrayContent(photo);
        file.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        return new MultipartFormDataContent { { file, "photo", "food.jpg" } };
    }

    [Fact]
    public async Task Admin_connects_chatgpt_checks_it_and_client_photos_are_analysed_by_openai()
    {
        var admin = await factory.AdminAsync();
        OpenAi.Reset();
        OpenAi.Handler = Answer;

        // A client who agreed while the server's own provider served AI.
        var (before, _) = await _s.RegisterClientAsync();
        (await before.PostAsync("/api/nutrition/ai-consent", null)).EnsureSuccessStatusCode();

        // Only admins with the integrations permission.
        var (client, _) = await _s.RegisterClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/admin/ai")).StatusCode);

        var settings = await ReadAsync(await admin.GetAsync("/api/admin/ai"));
        Assert.Equal(AiSettingsSource.Server, settings.Active.Source);
        Assert.False(settings.Keys["OpenAI"].IsSet);
        Assert.Equal("gpt-6.1-terra", settings.Providers.Single(p => p.Id == "OpenAI").DefaultVisionModel);

        try
        {
            // Switching on needs a key; keys are checked for format and for the right provider.
            var noKey = await UpdateAsync(admin, settings, enabled: true);
            Assert.Equal(("ai_key_missing", HttpStatusCode.Conflict), (await Scenario.ErrorCodeAsync(noKey), noKey.StatusCode));
            var shortKey = await admin.PutAsJsonAsync("/api/admin/ai/keys/OpenAI", new { value = "sk-short" }, Json);
            Assert.Equal("invalid_ai_key", await Scenario.ErrorCodeAsync(shortKey));
            var claudeKey = await admin.PutAsJsonAsync("/api/admin/ai/keys/OpenAI", new { value = "sk-ant-api03-0123456789abcdef" }, Json);
            Assert.Equal("ai_key_wrong_provider", await Scenario.ErrorCodeAsync(claudeKey));

            settings = await ReadAsync(await admin.PutAsJsonAsync("/api/admin/ai/keys/OpenAI", new { value = OpenAiKey }, Json));
            Assert.True(settings.Keys["OpenAI"].IsReadable);
            Assert.Equal("••••abcd", settings.Keys["OpenAI"].Mask);
            Assert.False(settings.IsEnabled);
            Assert.Equal(AiSettingsSource.Server, settings.Active.Source); // not switched on yet

            // The key is stored encrypted, never returned whole and never logged.
            using (var scope = factory.Services.CreateScope())
            {
                var row = await scope.ServiceProvider.GetRequiredService<AppDbContext>().AiProviderSettings.SingleAsync();
                Assert.DoesNotContain(OpenAiKey, row.OpenAiKeyCiphertext);
            }
            Assert.DoesNotContain(OpenAiKey, await (await admin.GetAsync("/api/admin/ai")).Content.ReadAsStringAsync());
            Assert.DoesNotContain(factory.Logs.Lines, m => m.Contains(OpenAiKey));

            // The check makes real requests with the key: a picture with a JSON answer, a tool call.
            settings = await ReadAsync(await admin.PostAsync("/api/admin/ai/check", null));
            var check = settings.LastCheck!;
            Assert.True(check.Ok, JsonSerializer.Serialize(check));
            Assert.Equal(["vision", "chat"], check.Steps.Select(x => x.Step));
            Assert.Equal("orange / green", check.Steps[0].Answer);
            Assert.Equal(("gpt-6.1-terra", "gpt-6.2-sol"), (check.Steps[0].Model, check.Steps[1].Model));
            var sent = OpenAi.Requests.ToArray();
            Assert.All(sent, r => Assert.Equal("Bearer " + OpenAiKey, r.Authorization));
            Assert.Contains(sent, r => r.Body["input"]![1]!["content"] is JsonArray c && c.Any(p => p?["type"]?.GetValue<string>() == "input_image"));

            // A failing check explains itself: a revoked key.
            OpenAi.Enqueue(401, FakeOpenAi.Error("invalid_api_key", "Incorrect API key provided: sk-proj-****abcd."));
            OpenAi.Enqueue(401, FakeOpenAi.Error("invalid_api_key", "Incorrect API key provided: sk-proj-****abcd."));
            var failed = (await ReadAsync(await admin.PostAsync("/api/admin/ai/check", null))).LastCheck!;
            Assert.False(failed.Ok);
            Assert.All(failed.Steps, x => Assert.Equal((401, "invalid_api_key"), (x.ProviderStatus, x.ProviderCode)));
            Assert.Contains("Incorrect API key", failed.Steps[0].Detail);

            // Switched on: OpenAI serves every AI request from now on, with no restart.
            settings = await ReadAsync(await admin.GetAsync("/api/admin/ai"));
            settings = await ReadAsync(await UpdateAsync(admin, settings, enabled: true, budget: 25));
            Assert.Equal((AiSettingsSource.Admin, "OpenAI", "gpt-6.1-terra", 25m),
                (settings.Active.Source, settings.Active.Provider, settings.Active.VisionModel, settings.Active.MonthlyBudgetUsd));
            var stale = await UpdateAsync(admin, settings with { Version = settings.Version + 1 }, enabled: false);
            Assert.Equal("concurrency_conflict", await Scenario.ErrorCodeAsync(stale));

            // The consent given for the previous provider does not cover OpenAI: the client is asked again.
            var profile = (await before.GetFromJsonAsync<NutritionProfileDto>("/api/nutrition/profile", Json))!;
            Assert.Null(profile.AiConsentAt);
            Assert.Equal("OpenAI (ChatGPT)", profile.AiProvider);
            var again = await before.PostAsync("/api/food-scanner/analyze", Form(FoodScannerTests.Photo("openai-before")));
            Assert.Equal("ai_consent_required", await Scenario.ErrorCodeAsync(again));

            // A client photo goes to OpenAI and the nutrition comes from the database as always.
            (await client.PostAsync("/api/nutrition/ai-consent", null)).EnsureSuccessStatusCode();
            OpenAi.Requests.Clear();
            var res = await client.PostAsync("/api/food-scanner/analyze", Form(FoodScannerTests.Photo("openai-photo")));
            Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
            var scan = (await res.Content.ReadFromJsonAsync<FoodScanDto>(Json))!;
            Assert.Equal(FoodScanStatus.Recognized, scan.Status);
            Assert.Equal(634m, Assert.Single(scan.Dishes).Totals.Values.Kcal);
            var photoRequest = Assert.Single(OpenAi.Requests);
            Assert.Equal("gpt-6.1-terra", photoRequest.Body["model"]!.GetValue<string>());
            Assert.Equal("FoodPhoto", photoRequest.Body["text"]!["format"]!["name"]!.GetValue<string>());
            Assert.Contains("rice_white_cooked", photoRequest.Body["input"]![0]!["content"]!.GetValue<string>());
            using (var scope = factory.Services.CreateScope())
            {
                // The test clock is shared with other tests, so the row is found by provider, not by time.
                var usage = await scope.ServiceProvider.GetRequiredService<AppDbContext>().AiUsage
                    .SingleAsync(u => u.Feature == AiFeature.FoodPhoto && u.Provider == "OpenAI");
                Assert.Equal(("OpenAI", "gpt-6.1-terra-2026-10-26", true), (usage.Provider, usage.Model, usage.Success));
                Assert.True(usage.CostUsd > 0); // priced as gpt-6.1-terra
            }

            // The privacy page names the service in use.
            Assert.Contains("OpenAI (США)", await factory.CreateClient().GetStringAsync("/legal/privacy"));

            // The key in use cannot be removed while switched on.
            var inUse = await admin.DeleteAsync("/api/admin/ai/keys/OpenAI");
            Assert.Equal("ai_key_in_use", await Scenario.ErrorCodeAsync(inUse));

            var audit = await admin.GetFromJsonAsync<List<Features.Integrations.AuditEntryDto>>("/api/admin/ai/audit", Json);
            Assert.Contains(audit!, a => a.Action == "ai_key_set");
            Assert.Contains(audit!, a => a.Action == "ai_checked");
            Assert.Contains(audit!, a => a.Action == "ai_settings_updated" && a.Details!.Contains("enabled"));
            Assert.DoesNotContain(audit!, a => a.Details?.Contains(OpenAiKey) == true);
        }
        finally
        {
            // Back to the server's own provider for the rest of the run.
            var current = await ReadAsync(await admin.GetAsync("/api/admin/ai"));
            await ReadAsync(await UpdateAsync(admin, current, enabled: false));
            (await admin.DeleteAsync("/api/admin/ai/keys/OpenAI")).EnsureSuccessStatusCode();
            OpenAi.Reset();
        }

        var after = await ReadAsync(await admin.GetAsync("/api/admin/ai"));
        Assert.Equal(AiSettingsSource.Server, after.Active.Source);
        Assert.False(after.Keys["OpenAI"].IsSet);
    }
}
