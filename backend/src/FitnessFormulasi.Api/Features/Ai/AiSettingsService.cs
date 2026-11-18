using System.ComponentModel.DataAnnotations;
using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Integrations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Ai;

public record AiKeyStateDto(bool IsSet, bool IsReadable, string? Mask, DateTimeOffset? UpdatedAt);

public record AiProviderOptionDto(
    string Id, string Name, string DefaultVisionModel, string DefaultChatModel, IReadOnlyList<string> Models, string KeysUrl);

/// <summary>What serves AI requests right now (the admin settings or the server configuration).</summary>
public record AiActiveDto(
    AiSettingsSource Source, string? Provider, string? ProviderName, string? VisionModel, string? ChatModel, decimal MonthlyBudgetUsd);

/// <summary>One real request of the connection check: the photo model with an image and JSON, the chat model with a tool.</summary>
public record AiCheckStepDto(
    string Step, string Model, bool Ok, int DurationMs, string? Answer, string? ErrorCode, int? ProviderStatus, string? ProviderCode,
    bool Billing, string? Detail);

public record AiCheckDto(DateTimeOffset At, string Provider, bool Ok, IReadOnlyList<AiCheckStepDto> Steps);

/// <summary>This calendar month (UTC): spending, all requests, failed requests and successful photo analyses.</summary>
public record AiUsageSummaryDto(decimal SpentUsd, int Requests, int Failed, int PhotoScans);

/// <summary>The AI settings for the admin panel. API keys are never included: only whether they are set and their last 4 characters.</summary>
public record AiSettingsDto(
    bool IsEnabled, string Provider, string? VisionModel, string? ChatModel, decimal? MonthlyBudgetUsd,
    IReadOnlyDictionary<string, AiKeyStateDto> Keys, IReadOnlyList<AiProviderOptionDto> Providers, AiActiveDto Active,
    decimal ServerMonthlyBudgetUsd, AiUsageSummaryDto Usage, AiCheckDto? LastCheck, bool EncryptionConfigured,
    DateTimeOffset? UpdatedAt, string? UpdatedBy, uint Version);

public class UpdateAiSettingsRequest
{
    public bool IsEnabled { get; set; }
    [Required, StringLength(16)] public string Provider { get; set; } = "";
    /// <summary>Empty: the provider's default model.</summary>
    [StringLength(64)] public string? VisionModel { get; set; }
    [StringLength(64)] public string? ChatModel { get; set; }
    /// <summary>Empty: the server's Ai:MonthlyBudgetUsd. 0: no cap.</summary>
    [Range(typeof(decimal), "0", "100000")] public decimal? MonthlyBudgetUsd { get; set; }
    /// <summary>Version from the last read; a stale version is rejected with 409.</summary>
    public uint Version { get; set; }
}

public class SetAiKeyRequest
{
    [Required, StringLength(512, MinimumLength = 1)] public string Value { get; set; } = "";
}

/// <summary>
/// The admin panel's AI settings: provider, API keys (encrypted, never returned or logged), models, monthly budget, and
/// a connection check that makes real requests. Every change is in the audit log and takes effect at once.
/// </summary>
public sealed partial class AiSettingsService(
    AppDbContext db, SecretProtector protector, AiConnectionProvider connections, AiGateway gateway, ICurrentUser currentUser,
    IClubClock clock, IOptions<AiOptions> options, ILogger<AiSettingsService> logger)
{
    private const string Target = "integration:AI";

    public async Task<AiSettingsDto> GetAsync(CancellationToken ct)
    {
        var s = await db.AiProviderSettings.AsNoTracking().OrderBy(x => x.CreatedAt).FirstOrDefaultAsync(ct) ?? new AiProviderSettings();
        var keys = new Dictionary<string, AiKeyStateDto>();
        foreach (var p in AiProviders.All)
        {
            var set = (p.Id == AiProviders.OpenAI ? s.OpenAiKeyCiphertext : s.AnthropicKeyCiphertext) is not null;
            var key = connections.KeyOf(s, p.Id);
            keys[p.Id] = new AiKeyStateDto(set, key is not null, key is null ? null : "••••" + key[^4..],
                p.Id == AiProviders.OpenAI ? s.OpenAiKeySetAt : s.AnthropicKeySetAt);
        }

        var active = await connections.GetAsync(ct);
        var since = gateway.MonthStart();
        var month = db.AiUsage.Where(u => u.CreatedAt >= since);
        var usage = new AiUsageSummaryDto(
            await month.SumAsync(u => (decimal?)u.CostUsd, ct) ?? 0, await month.CountAsync(ct), await month.CountAsync(u => !u.Success, ct),
            await month.CountAsync(u => u.Success && u.Feature == AiFeature.FoodPhoto, ct));
        var updatedBy = s.UpdatedByUserId is null ? null
            : await db.Users.Where(u => u.Id == s.UpdatedByUserId).Select(u => u.FirstName + " " + u.LastName).SingleOrDefaultAsync(ct);
        var check = s.LastCheckJson is null ? null : JsonSerializer.Deserialize<AiCheckDto>(s.LastCheckJson, JsonOptions);

        return new AiSettingsDto(s.IsEnabled, s.Provider, s.VisionModel, s.ChatModel, s.MonthlyBudgetUsd, keys,
            AiProviders.All.Select(p => new AiProviderOptionDto(p.Id, p.DisplayName, p.DefaultVisionModel, p.DefaultChatModel, p.Models, p.KeysUrl)).ToList(),
            new AiActiveDto(active.Source, active.IsConfigured ? active.Provider : null, active.DisplayName,
                active.IsConfigured ? active.VisionModel : null, active.IsConfigured ? active.ChatModel : null, active.MonthlyBudgetUsd),
            options.Value.MonthlyBudgetUsd, usage, check, protector.IsConfigured, s.ConfigChangedAt, updatedBy, s.Version);
    }

    public async Task<AiSettingsDto> UpdateAsync(UpdateAiSettingsRequest req, CancellationToken ct)
    {
        var info = AiProviders.Find(req.Provider) ?? throw ApiException.BadRequest("unknown_ai_provider", "Unknown AI provider.");
        var vision = ModelOrNull(req.VisionModel, "visionModel");
        var chat = ModelOrNull(req.ChatModel, "chatModel");

        var s = await db.AiProviderSettings.OrderBy(x => x.CreatedAt).FirstOrDefaultAsync(ct);
        if (s is null) db.AiProviderSettings.Add(s = new AiProviderSettings());
        else if (s.Version != req.Version)
            throw ApiException.Conflict("concurrency_conflict", "Settings were changed by someone else. Reload and try again.");

        var changes = new List<string>();
        if (s.IsEnabled != req.IsEnabled) changes.Add(req.IsEnabled ? "enabled" : "disabled");
        if (s.Provider != info.Id) changes.Add($"provider {s.Provider} -> {info.Id}");
        if (s.VisionModel != vision) changes.Add($"vision model {s.VisionModel ?? "default"} -> {vision ?? "default"}");
        if (s.ChatModel != chat) changes.Add($"chat model {s.ChatModel ?? "default"} -> {chat ?? "default"}");
        if (s.MonthlyBudgetUsd != req.MonthlyBudgetUsd)
            changes.Add($"monthly budget {s.MonthlyBudgetUsd?.ToString() ?? "server"} -> {req.MonthlyBudgetUsd?.ToString() ?? "server"}");
        if (changes.Count == 0 && db.Entry(s).State != EntityState.Added) return await GetAsync(ct);

        var connectionChanged = s.Provider != info.Id || s.VisionModel != vision || s.ChatModel != chat;
        s.IsEnabled = req.IsEnabled;
        s.Provider = info.Id;
        s.VisionModel = vision;
        s.ChatModel = chat;
        s.MonthlyBudgetUsd = req.MonthlyBudgetUsd;
        if (s.IsEnabled && connections.KeyOf(s, s.Provider) is null)
            throw ApiException.Conflict("ai_key_missing", "Set the API key of the selected provider before switching AI on.");
        if (connectionChanged) ClearCheck(s);

        Touch(s);
        Audit("ai_settings_updated", string.Join("; ", changes));
        await db.SaveChangesAsync(ct);
        connections.Invalidate();
        return await GetAsync(ct);
    }

    public async Task<AiSettingsDto> SetKeyAsync(string provider, string value, CancellationToken ct)
    {
        var info = AiProviders.Find(provider) ?? throw ApiException.NotFound("AI provider");
        if (!protector.IsConfigured)
            throw new ApiException(StatusCodes.Status409Conflict, "encryption_not_configured",
                "Secrets cannot be saved: the server encryption key is not configured.");
        value = value.Trim();
        if (!KeyFormat().IsMatch(value)) throw ApiException.BadRequest("invalid_ai_key", "The API key has an invalid format.");
        // The most common mistake: a Claude key in the OpenAI field or the other way round.
        var claudeKey = value.StartsWith("sk-ant-", StringComparison.Ordinal);
        if (info.Id == AiProviders.OpenAI ? claudeKey : !claudeKey)
            throw ApiException.BadRequest("ai_key_wrong_provider", "This key belongs to the other AI provider.");

        var s = await db.AiProviderSettings.OrderBy(x => x.CreatedAt).FirstOrDefaultAsync(ct);
        if (s is null) db.AiProviderSettings.Add(s = new AiProviderSettings { Provider = info.Id });
        var replaced = (info.Id == AiProviders.OpenAI ? s.OpenAiKeyCiphertext : s.AnthropicKeyCiphertext) is not null;
        var ciphertext = protector.Protect(value, AiConnectionProvider.KeyContext(info.Id));
        if (info.Id == AiProviders.OpenAI) (s.OpenAiKeyCiphertext, s.OpenAiKeySetAt) = (ciphertext, clock.UtcNow);
        else (s.AnthropicKeyCiphertext, s.AnthropicKeySetAt) = (ciphertext, clock.UtcNow);
        if (s.Provider == info.Id) ClearCheck(s);

        Touch(s);
        Audit(replaced ? "ai_key_replaced" : "ai_key_set", info.Id);
        await db.SaveChangesAsync(ct);
        connections.Invalidate();
        return await GetAsync(ct);
    }

    public async Task<AiSettingsDto> DeleteKeyAsync(string provider, CancellationToken ct)
    {
        var info = AiProviders.Find(provider) ?? throw ApiException.NotFound("AI provider");
        var s = await db.AiProviderSettings.OrderBy(x => x.CreatedAt).FirstOrDefaultAsync(ct);
        if (s is null || (info.Id == AiProviders.OpenAI ? s.OpenAiKeyCiphertext : s.AnthropicKeyCiphertext) is null)
            throw ApiException.NotFound("API key");
        if (s.IsEnabled && s.Provider == info.Id)
            throw ApiException.Conflict("ai_key_in_use", "Switch AI off or choose another provider before removing the key in use.");
        if (info.Id == AiProviders.OpenAI) (s.OpenAiKeyCiphertext, s.OpenAiKeySetAt) = (null, null);
        else (s.AnthropicKeyCiphertext, s.AnthropicKeySetAt) = (null, null);
        if (s.Provider == info.Id) ClearCheck(s);

        Touch(s);
        Audit("ai_key_removed", info.Id);
        await db.SaveChangesAsync(ct);
        connections.Invalidate();
        return await GetAsync(ct);
    }

    /// <summary>
    /// Real requests with the selected provider, key and models (switched on or not): the photo model gets a small
    /// picture and must answer JSON by a schema; the chat model must call a tool and use its result. No client data is
    /// sent. The tokens are recorded and count towards the monthly budget.
    /// </summary>
    public async Task<AiSettingsDto> CheckAsync(CancellationToken ct)
    {
        var s = await db.AiProviderSettings.OrderBy(x => x.CreatedAt).FirstOrDefaultAsync(ct);
        var key = s is null ? null : connections.KeyOf(s, s.Provider);
        if (s is null || key is null)
            throw ApiException.Conflict("ai_key_missing", "Set the API key of the selected provider first.");
        var connection = connections.Connect(s, key);
        var steps = new List<AiCheckStepDto>
        {
            await StepAsync("vision", connection.VisionModel, connection, async () =>
            {
                var r = await connection.Client.GenerateJsonAsync(new AiJsonRequest(AiFeature.ConnectionCheck, CheckSystem,
                    "What colour is the round shape in the middle of this picture, and what colour is the background? One English word each.",
                    [new AiImage(Convert.FromBase64String(CheckImage), "image/jpeg")], CheckSchema(), 4000)
                {
                    Model = connection.VisionModel, Effort = "low",
                }, ct);
                using var json = JsonDocument.Parse(r.Json);
                var answer = $"{json.RootElement.GetProperty("shape").GetString()} / {json.RootElement.GetProperty("background").GetString()}";
                return (r.Model, r.Usage, answer, true);
            }, ct),
            await StepAsync("chat", connection.ChatModel, connection, async () =>
            {
                var r = await connection.Client.ChatAsync(new AiChatRequest(AiFeature.ConnectionCheck, CheckSystem,
                    [new AiChatMessage("user", "Call the tool get_check_number and answer with the number it returns, digits only.")],
                    [new AiToolDefinition("get_check_number", "Returns the number of this connection check.",
                        new JsonObject { ["type"] = "object", ["properties"] = new JsonObject(), ["additionalProperties"] = false })],
                    4000, 2) { Model = connection.ChatModel, Effort = "low" },
                    (_, _) => Task.FromResult("{\"number\":4217}"), ct);
                return (r.Model, r.Usage, r.Text.Length > 200 ? r.Text[..200] : r.Text, r.ToolsUsed.Contains("get_check_number") && r.Text.Contains("4217"));
            }, ct),
        };

        var result = new AiCheckDto(clock.UtcNow, s.Provider, steps.All(x => x.Ok), steps);
        s.LastCheckAt = result.At;
        s.LastCheckOk = result.Ok;
        s.LastCheckJson = JsonSerializer.Serialize(result, JsonOptions);
        Audit("ai_checked", $"{s.Provider}: {(result.Ok ? "ok" : "failed")} ({string.Join(", ", steps.Select(x => $"{x.Step} {x.Model} {(x.Ok ? "ok" : x.ErrorCode)}"))})");
        await db.SaveChangesAsync(ct);
        return await GetAsync(ct);
    }

    public async Task<List<AuditEntryDto>> AuditAsync(CancellationToken ct) =>
        await db.AuditLog.Where(a => a.Target == Target).OrderByDescending(a => a.CreatedAt).ThenBy(a => a.Id).Take(50)
            .Select(a => new AuditEntryDto(a.CreatedAt, a.Action, a.Target, a.Details,
                db.Users.Where(u => u.Id == a.UserId).Select(u => u.FirstName + " " + u.LastName).FirstOrDefault()))
            .ToListAsync(ct);

    private async Task<AiCheckStepDto> StepAsync(string step, string model, AiConnection connection,
        Func<Task<(string Model, AiUsage Usage, string Answer, bool Ok)>> run, CancellationToken ct)
    {
        var watch = Stopwatch.StartNew();
        try
        {
            var (used, usage, answer, ok) = await run();
            await gateway.RecordAsync(null, AiFeature.ConnectionCheck, connection.Provider, used, usage, watch.Elapsed,
                ok ? null : "unexpected_answer", ct);
            return new AiCheckStepDto(step, model, ok, (int)watch.ElapsedMilliseconds, answer, ok ? null : "unexpected_answer", null, null,
                false, ok ? null : "The model answered, but not as asked.");
        }
        catch (AiException e)
        {
            await gateway.RecordAsync(null, AiFeature.ConnectionCheck, connection.Provider, e.Model ?? model, e.Usage, watch.Elapsed, e.Code, ct);
            return new AiCheckStepDto(step, model, false, (int)watch.ElapsedMilliseconds, null, e.Code, e.ProviderStatus, e.ProviderCode,
                e.ProviderStatus is { } st && OpenAiClient.IsBillingError(st, null, e.ProviderCode), e.Detail ?? e.Message);
        }
        catch (Exception e) when (e is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            logger.LogWarning(e, "AI connection check: unexpected answer");
            return new AiCheckStepDto(step, model, false, (int)watch.ElapsedMilliseconds, null, "ai_invalid_response", null, null, false,
                "The answer does not follow the JSON schema: " + e.Message);
        }
    }

    private static string? ModelOrNull(string? value, string field)
    {
        var v = value?.Trim();
        if (string.IsNullOrEmpty(v)) return null;
        if (!ModelFormat().IsMatch(v)) throw ApiException.BadRequest("invalid_ai_model", $"Field '{field}' is not a model id.");
        return v;
    }

    private static void ClearCheck(AiProviderSettings s) => (s.LastCheckAt, s.LastCheckOk, s.LastCheckJson) = (null, null, null);

    private void Touch(AiProviderSettings s)
    {
        s.ConfigChangedAt = clock.UtcNow;
        s.UpdatedByUserId = currentUser.Id;
    }

    private void Audit(string action, string details)
    {
        db.AuditLog.Add(new AuditLogEntry { UserId = currentUser.Id, Action = action, Target = Target, Details = details });
        // Names and non-secret values only, never a key.
        logger.LogInformation("AI settings: {Action} by {UserId} ({Details})", action, currentUser.Id, details);
    }

    private static JsonObject CheckSchema() => new()
    {
        ["type"] = "object",
        ["additionalProperties"] = false,
        ["required"] = new JsonArray("shape", "background"),
        ["properties"] = new JsonObject
        {
            ["shape"] = new JsonObject { ["type"] = "string" },
            ["background"] = new JsonObject { ["type"] = "string" },
        },
    };

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter() },
    };

    private const string CheckSystem = "You are checking that an API connection works. Follow the request exactly and keep the answer short.";

    /// <summary>A generated 64×64 JPEG: an orange disc on a green background.</summary>
    private const string CheckImage = "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";

    [GeneratedRegex(@"^\S{20,512}$")]
    private static partial Regex KeyFormat();

    [GeneratedRegex(@"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,63}$")]
    private static partial Regex ModelFormat();
}
