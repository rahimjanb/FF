namespace FitnessFormulasi.Api.Domain;

/// <summary>
/// Face photo of a client for the face recognition terminals at the entrance (Hikvision DS-K1T343MFWX and similar).
/// Biometric personal data: uploaded only with the client's consent, never served anonymously, removed from the
/// terminals when deleted. Kept apart from the profile so profile queries never load the bytes.
/// </summary>
public class ClientFace
{
    public Guid ClientProfileId { get; set; }
    public ClientProfile ClientProfile { get; set; } = null!;
    /// <summary>JPEG, at most 200 KB: the terminals accept nothing else.</summary>
    public required byte[] Data { get; set; }
    /// <summary>Bumped on every replacement, so the terminals receive the new photo.</summary>
    public int Version { get; set; } = 1;
    public DateTimeOffset UploadedAt { get; set; }
    /// <summary>The client in the app, or the administrator at the desk.</summary>
    public Guid? UploadedByUserId { get; set; }
    /// <summary>When consent to processing the face photo for entry was given (with the latest upload).</summary>
    public DateTimeOffset ConsentAt { get; set; }
}

/// <summary>
/// A face recognition terminal that controls the turnstile, reached over ISAPI (HTTP with Digest authentication) in
/// the club network. The API keeps the people on it in step with memberships; the terminal decides on entry by
/// itself, so it keeps working while the server is unreachable.
/// </summary>
public class AccessDevice : Entity
{
    public required string Name { get; set; }
    /// <summary>Scheme, host and optional port, e.g. <c>http://192.168.1.64</c>.</summary>
    public required string BaseUrl { get; set; }
    public required string Username { get; set; }
    /// <summary>Device password encrypted with <c>SecretProtector</c> (AES-256-GCM).</summary>
    public string? PasswordCiphertext { get; set; }
    /// <summary>Switched off devices are neither synchronised nor accept events.</summary>
    public bool IsActive { get; set; } = true;
    /// <summary>Entry terminal: a pass records a visit. Exit terminals only let people out.</summary>
    public bool RecordsVisits { get; set; } = true;
    /// <summary>Door (relay) number the client is allowed through; 1 on single-door terminals.</summary>
    public int DoorNo { get; set; } = 1;
    /// <summary>Random secret in the URL the terminal posts events to, since it cannot sign its requests.</summary>
    public required string EventToken { get; set; }

    public string? Model { get; set; }
    public string? SerialNumber { get; set; }
    public string? Firmware { get; set; }
    /// <summary>Last successful request from the API to the device.</summary>
    public DateTimeOffset? LastContactAt { get; set; }
    /// <summary>Last event or heartbeat the device sent.</summary>
    public DateTimeOffset? LastEventAt { get; set; }
    public string? LastError { get; set; }
    public DateTimeOffset? LastErrorAt { get; set; }
}

/// <summary>Pending: not written yet. Failed: the device refused or failed, retried later. PhotoRejected: the terminal could not find a face in the photo; waits for a new photo.</summary>
public enum AccessSyncState { Pending, Synced, Failed, PhotoRejected }

/// <summary>What a terminal holds for a client, as last confirmed by the terminal.</summary>
public class AccessDeviceUser
{
    public Guid AccessDeviceId { get; set; }
    public AccessDevice Device { get; set; } = null!;
    public Guid ClientProfileId { get; set; }
    public ClientProfile ClientProfile { get; set; } = null!;
    /// <summary>Person id on the terminal (ISAPI employeeNo): <see cref="ClientProfile.AccessNo"/>.</summary>
    public required string EmployeeNo { get; set; }
    /// <summary>Name and validity period last written, e.g. "2026-11-01/2027-10-31/Иван Петров"; null until written.</summary>
    public string? AccessKey { get; set; }
    /// <summary><see cref="ClientFace.Version"/> on the terminal; 0 = no face yet.</summary>
    public int FaceVersion { get; set; }
    /// <summary>Photo version the terminal refused; not sent again until the client uploads a new one.</summary>
    public int? RejectedFaceVersion { get; set; }
    public AccessSyncState State { get; set; }
    public string? LastError { get; set; }
    public int FailedAttempts { get; set; }
    public DateTimeOffset? RetryAt { get; set; }
    public DateTimeOffset? SyncedAt { get; set; }
}

/// <summary>A pass or refusal reported by a terminal; the journal of the turnstile.</summary>
public class AccessEvent : Entity
{
    public Guid? AccessDeviceId { get; set; }
    public AccessDevice? Device { get; set; }
    public required string DeviceName { get; set; }
    /// <summary>Event number on the device, used to ignore repeated deliveries.</summary>
    public long? SerialNo { get; set; }
    public DateTimeOffset OccurredAt { get; set; }
    public int Major { get; set; }
    public int Minor { get; set; }
    public bool Granted { get; set; }
    public string? EmployeeNo { get; set; }
    public Guid? ClientProfileId { get; set; }
    public ClientProfile? ClientProfile { get; set; }
    public Guid? VisitId { get; set; }
    /// <summary>Why no visit was recorded for a pass, e.g. <c>no_membership</c> (the terminal was out of date).</summary>
    public string? Note { get; set; }
}
