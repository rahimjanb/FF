using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Integrations;

/// <summary>
/// NotConfigured: a required field of the selected mode is missing. Configured: complete but switched off.
/// NeedsVerification: switched on, but no provider request has passed signature checks since the last change.
/// Active: switched on and verified by a real provider request after the last change (stage 2 callbacks).
/// </summary>
public enum IntegrationStatus { NotConfigured, Configured, NeedsVerification, Active }

public record IntegrationSecretStateDto(bool IsSet, bool IsReadable, string? Mask, DateTimeOffset? UpdatedAt);

public record IntegrationModeDto(
    IReadOnlyDictionary<string, string?> Values, IReadOnlyDictionary<string, IntegrationSecretStateDto> Secrets,
    IReadOnlyList<string> MissingFields);

public record IntegrationFieldDto(string Name, bool IsSecret);

/// <summary>Settings of one provider. Secret values are never included: only whether they are set.</summary>
public record IntegrationDto(
    IntegrationProvider Provider, IntegrationStatus Status, bool IsEnabled, IntegrationMode Mode,
    IReadOnlyList<IntegrationFieldDto> Fields, IntegrationModeDto Test, IntegrationModeDto Production,
    DateTimeOffset? UpdatedAt, string? UpdatedBy, DateTimeOffset? LastVerifiedAt, bool EncryptionConfigured, uint Version);

public record AuditEntryDto(DateTimeOffset CreatedAt, string Action, string Target, string? Details, string? UserName);

public class UpdateIntegrationRequest
{
    public bool IsEnabled { get; set; }
    [Required] public IntegrationMode Mode { get; set; }
    /// <summary>Non-secret values per mode. Secrets are changed only through the secret endpoints.</summary>
    public Dictionary<string, string?> Test { get; set; } = [];
    public Dictionary<string, string?> Production { get; set; } = [];
    /// <summary>Version from the last read; a stale version is rejected with 409.</summary>
    public uint Version { get; set; }
}

public class SetSecretRequest
{
    [Required, StringLength(256, MinimumLength = 1)] public string Value { get; set; } = "";
}

public sealed class IntegrationSettingsService(
    AppDbContext db, SecretProtector protector, ICurrentUser currentUser, IClubClock clock,
    ILogger<IntegrationSettingsService> logger)
{
    private const string Mask = "••••••••";

    public async Task<List<IntegrationDto>> ListAsync(CancellationToken ct)
    {
        var list = new List<IntegrationDto>();
        foreach (var provider in Enum.GetValues<IntegrationProvider>()) list.Add(await GetAsync(provider, ct));
        return list;
    }

    public async Task<IntegrationDto> GetAsync(IntegrationProvider provider, CancellationToken ct)
    {
        var setting = await db.IntegrationSettings.AsNoTracking().SingleOrDefaultAsync(s => s.Provider == provider, ct)
                      ?? new IntegrationSetting { Provider = provider };
        var secrets = await db.IntegrationSecrets.AsNoTracking().Where(s => s.Provider == provider).ToListAsync(ct);
        var updatedBy = setting.UpdatedByUserId is null ? null
            : await db.Users.Where(u => u.Id == setting.UpdatedByUserId).Select(u => u.FirstName + " " + u.LastName).SingleOrDefaultAsync(ct);

        var test = ModeState(provider, IntegrationMode.Test, setting.TestValuesJson, secrets);
        var production = ModeState(provider, IntegrationMode.Production, setting.ProductionValuesJson, secrets);
        var current = setting.Mode == IntegrationMode.Test ? test : production;
        var verified = setting.LastVerifiedAt is not null && setting.LastVerifiedAt > setting.ConfigChangedAt;
        var status = current.MissingFields.Count > 0 ? IntegrationStatus.NotConfigured
            : !setting.IsEnabled ? IntegrationStatus.Configured
            : verified ? IntegrationStatus.Active
            : IntegrationStatus.NeedsVerification;

        return new IntegrationDto(provider, status, setting.IsEnabled, setting.Mode,
            IntegrationCatalog.Fields[provider].Select(f => new IntegrationFieldDto(f.Name, f.IsSecret)).ToList(),
            test, production, setting.ConfigChangedAt, updatedBy, setting.LastVerifiedAt, protector.IsConfigured, setting.Version);
    }

    public async Task<IntegrationDto> UpdateAsync(IntegrationProvider provider, UpdateIntegrationRequest req, CancellationToken ct)
    {
        var test = Normalize(provider, req.Test, "test");
        var production = Normalize(provider, req.Production, "production");

        var setting = await db.IntegrationSettings.SingleOrDefaultAsync(s => s.Provider == provider, ct);
        if (setting is null)
        {
            setting = new IntegrationSetting { Provider = provider };
            db.IntegrationSettings.Add(setting);
        }
        else if (setting.Version != req.Version)
        {
            throw ApiException.Conflict("concurrency_conflict", "Settings were changed by someone else. Reload and try again.");
        }

        var changes = new List<string>();
        if (setting.IsEnabled != req.IsEnabled) changes.Add(req.IsEnabled ? "enabled" : "disabled");
        if (setting.Mode != req.Mode) changes.Add($"mode {setting.Mode} -> {req.Mode}");
        changes.AddRange(ChangedFields(setting.TestValuesJson, test, "test"));
        changes.AddRange(ChangedFields(setting.ProductionValuesJson, production, "production"));
        if (changes.Count == 0) return await GetAsync(provider, ct);

        setting.IsEnabled = req.IsEnabled;
        setting.Mode = req.Mode;
        setting.TestValuesJson = JsonSerializer.Serialize(test);
        setting.ProductionValuesJson = JsonSerializer.Serialize(production);

        // Switching on requires a complete configuration of the selected mode.
        if (setting.IsEnabled)
        {
            var secrets = await db.IntegrationSecrets.AsNoTracking().Where(s => s.Provider == provider).ToListAsync(ct);
            var missing = ModeState(provider, setting.Mode,
                setting.Mode == IntegrationMode.Test ? setting.TestValuesJson : setting.ProductionValuesJson, secrets).MissingFields;
            if (missing.Count > 0)
                throw new ApiException(StatusCodes.Status409Conflict, "integration_incomplete",
                    "Fill in all fields of the selected mode before switching the integration on: " + string.Join(", ", missing));
        }

        Touch(setting);
        Audit("integration_updated", provider, string.Join("; ", changes));
        await db.SaveChangesAsync(ct);
        return await GetAsync(provider, ct);
    }

    /// <summary>Sets or replaces a secret. Requires the encryption key; the value is never logged or returned.</summary>
    public async Task<IntegrationDto> SetSecretAsync(IntegrationProvider provider, IntegrationMode mode, string name, string value,
        CancellationToken ct)
    {
        var field = SecretField(provider, name);
        if (!protector.IsConfigured)
            throw new ApiException(StatusCodes.Status409Conflict, "encryption_not_configured",
                "Secrets cannot be saved: the server encryption key is not configured.");
        value = value.Trim();
        if (!field.Format.IsMatch(value))
            throw ApiException.BadRequest("invalid_secret", "The secret has an invalid format.");

        var setting = await EnsureSettingAsync(provider, ct);
        var secret = await db.IntegrationSecrets.SingleOrDefaultAsync(s => s.Provider == provider && s.Mode == mode && s.Name == name, ct);
        var ciphertext = protector.Protect(value, Context(provider, mode, name));
        if (secret is null)
            db.IntegrationSecrets.Add(new IntegrationSecret { Provider = provider, Mode = mode, Name = name, Ciphertext = ciphertext });
        else
            secret.Ciphertext = ciphertext;

        Touch(setting);
        Audit(secret is null ? "secret_set" : "secret_replaced", provider, $"{Key(mode)}.{name}");
        await db.SaveChangesAsync(ct);
        return await GetAsync(provider, ct);
    }

    public async Task<IntegrationDto> DeleteSecretAsync(IntegrationProvider provider, IntegrationMode mode, string name, CancellationToken ct)
    {
        SecretField(provider, name);
        var setting = await EnsureSettingAsync(provider, ct);
        if (setting.IsEnabled && setting.Mode == mode)
            throw new ApiException(StatusCodes.Status409Conflict, "integration_enabled",
                "Switch the integration off before removing a secret of the active mode.");
        var secret = await db.IntegrationSecrets.SingleOrDefaultAsync(s => s.Provider == provider && s.Mode == mode && s.Name == name, ct)
                     ?? throw ApiException.NotFound("Secret");
        db.IntegrationSecrets.Remove(secret);
        Touch(setting);
        Audit("secret_removed", provider, $"{Key(mode)}.{name}");
        await db.SaveChangesAsync(ct);
        return await GetAsync(provider, ct);
    }

    public async Task<List<AuditEntryDto>> AuditAsync(IntegrationProvider provider, CancellationToken ct)
    {
        var target = Target(provider);
        return await db.AuditLog.Where(a => a.Target == target).OrderByDescending(a => a.CreatedAt).ThenBy(a => a.Id).Take(50)
            .Select(a => new AuditEntryDto(a.CreatedAt, a.Action, a.Target, a.Details,
                db.Users.Where(u => u.Id == a.UserId).Select(u => u.FirstName + " " + u.LastName).FirstOrDefault()))
            .ToListAsync(ct);
    }

    private IntegrationModeDto ModeState(IntegrationProvider provider, IntegrationMode mode, string valuesJson,
        List<IntegrationSecret> secrets)
    {
        var stored = Parse(valuesJson);
        var values = new Dictionary<string, string?>();
        var secretStates = new Dictionary<string, IntegrationSecretStateDto>();
        var missing = new List<string>();
        foreach (var f in IntegrationCatalog.Fields[provider])
        {
            if (f.IsSecret)
            {
                var s = secrets.FirstOrDefault(x => x.Mode == mode && x.Name == f.Name);
                // A secret that no longer decrypts (key changed) is reported so the admin can enter it again.
                var readable = s is not null && protector.Unprotect(s.Ciphertext, Context(provider, mode, f.Name)) is not null;
                secretStates[f.Name] = new IntegrationSecretStateDto(s is not null, readable, s is null ? null : Mask, s?.UpdatedAt);
                if (!readable) missing.Add(f.Name);
            }
            else
            {
                var v = stored.GetValueOrDefault(f.Name);
                values[f.Name] = v;
                if (string.IsNullOrEmpty(v)) missing.Add(f.Name);
            }
        }
        return new IntegrationModeDto(values, secretStates, missing);
    }

    private static Dictionary<string, string> Normalize(IntegrationProvider provider, Dictionary<string, string?> input, string mode)
    {
        var result = new Dictionary<string, string>();
        foreach (var (name, raw) in input)
        {
            var field = IntegrationCatalog.Find(provider, name);
            if (field is null || field.IsSecret)
                throw ApiException.BadRequest("unknown_field", $"Field '{mode}.{name}' cannot be set here.");
            var value = raw?.Trim();
            if (string.IsNullOrEmpty(value)) continue; // empty clears a non-secret field
            if (!field.Format.IsMatch(value))
                throw ApiException.BadRequest("invalid_field", $"Field '{mode}.{name}' has an invalid format.");
            result[name] = value;
        }
        return result;
    }

    private static IEnumerable<string> ChangedFields(string oldJson, Dictionary<string, string> next, string mode)
    {
        var old = Parse(oldJson);
        return old.Keys.Union(next.Keys).Where(k => old.GetValueOrDefault(k) != next.GetValueOrDefault(k)).Select(k => $"{mode}.{k}");
    }

    private static Dictionary<string, string> Parse(string json) =>
        JsonSerializer.Deserialize<Dictionary<string, string>>(json) ?? [];

    private static IntegrationField SecretField(IntegrationProvider provider, string name) =>
        IntegrationCatalog.Find(provider, name) is { IsSecret: true } f ? f : throw ApiException.NotFound("Secret field");

    private async Task<IntegrationSetting> EnsureSettingAsync(IntegrationProvider provider, CancellationToken ct)
    {
        var setting = await db.IntegrationSettings.SingleOrDefaultAsync(s => s.Provider == provider, ct);
        if (setting is not null) return setting;
        setting = new IntegrationSetting { Provider = provider };
        db.IntegrationSettings.Add(setting);
        return setting;
    }

    private void Touch(IntegrationSetting setting)
    {
        setting.ConfigChangedAt = clock.UtcNow;
        setting.UpdatedByUserId = currentUser.Id;
    }

    private void Audit(string action, IntegrationProvider provider, string details)
    {
        db.AuditLog.Add(new AuditLogEntry { UserId = currentUser.Id, Action = action, Target = Target(provider), Details = details });
        // Only names of changed fields are logged, never values.
        logger.LogInformation("Integration {Provider}: {Action} by {UserId} ({Details})", provider, action, currentUser.Id, details);
    }

    private static string Target(IntegrationProvider provider) => $"integration:{provider}";
    private static string Key(IntegrationMode mode) => mode == IntegrationMode.Test ? "test" : "production";
    private static string Context(IntegrationProvider provider, IntegrationMode mode, string name) => $"{provider}/{mode}/{name}";
}
