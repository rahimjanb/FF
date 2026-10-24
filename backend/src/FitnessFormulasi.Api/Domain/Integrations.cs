namespace FitnessFormulasi.Api.Domain;

/// <summary>Payment providers the club can connect. Online payments are stage 2; stage 1 stores settings only.</summary>
public enum IntegrationProvider { Click, Payme }

/// <summary>Each provider has separate test and production credentials; <see cref="IntegrationSetting.Mode"/> picks one.</summary>
public enum IntegrationMode { Test, Production }

/// <summary>Non-secret settings of one provider. Secrets live encrypted in <see cref="IntegrationSecret"/>.</summary>
public class IntegrationSetting : Entity
{
    public IntegrationProvider Provider { get; set; }
    public bool IsEnabled { get; set; }
    public IntegrationMode Mode { get; set; } = IntegrationMode.Test;
    /// <summary>Non-secret field values (JSON object of strings) for each mode.</summary>
    public string TestValuesJson { get; set; } = "{}";
    public string ProductionValuesJson { get; set; } = "{}";
    /// <summary>Last change of anything that affects the connection; a verification older than this no longer counts.</summary>
    public DateTimeOffset? ConfigChangedAt { get; set; }
    /// <summary>
    /// Last request from the provider that passed signature/authorization checks with the current configuration.
    /// Set only by real provider callbacks (stage 2); never by the admin panel.
    /// </summary>
    public DateTimeOffset? LastVerifiedAt { get; set; }
    public Guid? UpdatedByUserId { get; set; }
    /// <summary>Optimistic concurrency token (PostgreSQL xmin).</summary>
    public uint Version { get; set; }
}

/// <summary>One encrypted secret (AES-GCM). The plaintext is never stored or returned by the API.</summary>
public class IntegrationSecret : Entity
{
    public IntegrationProvider Provider { get; set; }
    public IntegrationMode Mode { get; set; }
    public required string Name { get; set; }
    public required string Ciphertext { get; set; }
}

/// <summary>Who changed what in sensitive settings. Never contains secret values.</summary>
public class AuditLogEntry : Entity
{
    public Guid? UserId { get; set; }
    public required string Action { get; set; }
    public required string Target { get; set; }
    /// <summary>Human-readable details: changed field names and non-secret values.</summary>
    public string? Details { get; set; }
}
