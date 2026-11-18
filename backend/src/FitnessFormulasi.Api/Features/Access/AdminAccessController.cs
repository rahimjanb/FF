using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Integrations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Access;

/// <summary>
/// Clients on the terminal compared with the plan. Planned: should be on it (face photo and days to enter).
/// Pending: not written yet or out of date, including people still to be removed.
/// </summary>
public record AccessDeviceStatsDto(int Planned, int Synced, int Pending, int Failed, int PhotoRejected);

/// <summary>A terminal. The password is never returned; <see cref="EventPath"/> is the address the device posts events to.</summary>
public record AccessDeviceDto(
    Guid Id, string Name, string BaseUrl, string Username, bool HasPassword, bool IsActive, bool RecordsVisits, int DoorNo,
    string EventPath, string? Model, string? SerialNumber, string? Firmware, DateTimeOffset? LastContactAt, DateTimeOffset? LastEventAt,
    string? LastError, DateTimeOffset? LastErrorAt, AccessDeviceStatsDto Stats, bool EncryptionConfigured);

/// <summary>
/// Result of a connection check. <see cref="ClockSkewSeconds"/>: terminal time minus server time.
/// <see cref="TimeZoneMatches"/>: the terminal's UTC offset equals the club's (validity periods are in terminal time).
/// </summary>
public record AccessDeviceCheckDto(bool Ok, string? Error, int? ClockSkewSeconds, bool? TimeZoneMatches, AccessDeviceDto Device);

public record AccessSyncResultDto(AccessSyncReport Report, AccessDeviceDto Device);

public record AccessIssueDto(
    Guid ClientId, string ClientName, string EmployeeNo, AccessSyncState State, string? LastError, int FailedAttempts, DateTimeOffset? RetryAt);

public record AccessEventDto(
    Guid Id, DateTimeOffset OccurredAt, Guid? DeviceId, string DeviceName, bool Granted, int Minor, string? EmployeeNo,
    PersonRef? Client, Guid? VisitId, string? Note);

public class SaveAccessDeviceRequest
{
    [Required, StringLength(64, MinimumLength = 1)] public string Name { get; set; } = "";
    /// <summary>IP address or host of the terminal, with an optional port and scheme: <c>192.168.1.64</c>, <c>http://10.0.0.5:8080</c>.</summary>
    [Required, StringLength(200, MinimumLength = 1)] public string Address { get; set; } = "";
    [Required, StringLength(32, MinimumLength = 1)] public string Username { get; set; } = "admin";
    /// <summary>Required for a new device; on update, empty keeps the saved password.</summary>
    [StringLength(64)] public string? Password { get; set; }
    public bool IsActive { get; set; } = true;
    public bool RecordsVisits { get; set; } = true;
    [Range(1, 8)] public int DoorNo { get; set; } = 1;
}

/// <summary>
/// Face recognition terminals (Hikvision ISAPI). Connection settings include the device password, so they are
/// managed by administrators with the integrations permission; the pass journal is open to all administrators.
/// </summary>
[ApiController]
[Route("api/admin/access")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminAccessController(
    AppDbContext db, IClubClock clock, ICurrentUser currentUser, AccessPlanner planner, AccessSyncService sync,
    HikvisionTerminalFactory terminals, SecretProtector protector) : ControllerBase
{
    public static string EventPath(string token) => $"/api/access/hikvision/events/{token}";

    [HttpGet("devices")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<List<AccessDeviceDto>> Devices(CancellationToken ct)
    {
        var devices = await db.AccessDevices.AsNoTracking().OrderBy(d => d.Name).ToListAsync(ct);
        return await ToDtosAsync(devices, ct);
    }

    [HttpGet("devices/{id:guid}")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<AccessDeviceDto> Device(Guid id, CancellationToken ct) => await DtoAsync(id, ct);

    [HttpPost("devices")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<ActionResult<AccessDeviceDto>> Create(SaveAccessDeviceRequest req, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(req.Password))
            throw ApiException.BadRequest("device_password_required", "Enter the password of the device account.");
        var device = new AccessDevice
        {
            Name = req.Name.Trim(), BaseUrl = NormalizeAddress(req.Address), Username = req.Username.Trim(),
            EventToken = Base64Url(RandomNumberGenerator.GetBytes(24)),
        };
        Apply(device, req);
        device.PasswordCiphertext = Protect(device.Id, req.Password);
        db.AccessDevices.Add(device);
        Audit("access_device_created", device, $"{device.Name}, {device.BaseUrl}");
        await db.SaveChangesAsync(ct);
        return StatusCode(StatusCodes.Status201Created, await DtoAsync(device.Id, ct));
    }

    [HttpPut("devices/{id:guid}")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<AccessDeviceDto> Update(Guid id, SaveAccessDeviceRequest req, CancellationToken ct)
    {
        // No optimistic locking: synchronisation updates the status fields of the row all the time.
        var device = await db.AccessDevices.SingleOrDefaultAsync(d => d.Id == id, ct) ?? throw ApiException.NotFound("Device");
        var address = NormalizeAddress(req.Address);
        var changes = new List<string>();
        if (device.Name != req.Name.Trim()) changes.Add("name");
        if (device.BaseUrl != address) changes.Add($"address {device.BaseUrl} -> {address}");
        if (device.Username != req.Username.Trim()) changes.Add("username");
        if (!string.IsNullOrEmpty(req.Password)) changes.Add("password");
        if (device.IsActive != req.IsActive) changes.Add(req.IsActive ? "switched on" : "switched off");
        if (device.RecordsVisits != req.RecordsVisits) changes.Add(req.RecordsVisits ? "records visits" : "does not record visits");
        if (device.DoorNo != req.DoorNo) changes.Add($"door {device.DoorNo} -> {req.DoorNo}");

        // Another device (or a reset one) at the address: what it holds is unknown, so everyone is written again.
        if (device.BaseUrl != address || device.DoorNo != req.DoorNo)
            await db.AccessDeviceUsers.Where(u => u.AccessDeviceId == id).ExecuteDeleteAsync(ct);
        device.Name = req.Name.Trim();
        device.BaseUrl = address;
        device.Username = req.Username.Trim();
        Apply(device, req);
        if (!string.IsNullOrEmpty(req.Password)) device.PasswordCiphertext = Protect(device.Id, req.Password);
        if (changes.Count > 0) Audit("access_device_updated", device, string.Join("; ", changes));
        await db.SaveChangesAsync(ct);
        return await DtoAsync(id, ct);
    }

    /// <summary>Forgets the device. The people already on it stay there until removed on the device itself.</summary>
    [HttpDelete("devices/{id:guid}")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var device = await db.AccessDevices.SingleOrDefaultAsync(d => d.Id == id, ct) ?? throw ApiException.NotFound("Device");
        db.AccessDevices.Remove(device);
        Audit("access_device_deleted", device, device.Name);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>Connects to the device and reads its model, serial number, firmware and clock.</summary>
    [HttpPost("devices/{id:guid}/check")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<AccessDeviceCheckDto> Check(Guid id, CancellationToken ct)
    {
        var device = await db.AccessDevices.SingleOrDefaultAsync(d => d.Id == id, ct) ?? throw ApiException.NotFound("Device");
        var password = device.PasswordCiphertext is null ? null : protector.Unprotect(device.PasswordCiphertext, AccessSyncService.PasswordContext(id));
        if (password is null)
            return new AccessDeviceCheckDto(false, "The device password is not set or cannot be decrypted; enter it again.", null, null, await DtoAsync(id, ct));

        using var terminal = terminals.Create(device.BaseUrl, device.Username, password);
        try
        {
            var info = await terminal.GetInfoAsync(ct);
            var now = clock.UtcNow;
            device.Model = Cut(info.Model);
            device.SerialNumber = Cut(info.SerialNumber);
            device.Firmware = Cut(info.Firmware);
            device.LastContactAt = now;
            device.LastError = null;
            device.LastErrorAt = null;
            await db.SaveChangesAsync(ct);
            int? skew = info.LocalTime is { } t ? (int)Math.Round((t - now).TotalSeconds) : null;
            bool? zone = info.LocalTime is { } lt ? lt.Offset == clock.TimeZone.GetUtcOffset(now) : null;
            return new AccessDeviceCheckDto(true, null, skew, zone, await DtoAsync(id, ct));
        }
        catch (IsapiException e)
        {
            device.LastError = e.Message.Length <= 500 ? e.Message : e.Message[..500];
            device.LastErrorAt = clock.UtcNow;
            await db.SaveChangesAsync(ct);
            return new AccessDeviceCheckDto(false, device.LastError, null, null, await DtoAsync(id, ct));
        }
    }

    /// <summary>Synchronises the device now, retrying clients that failed recently. Runs up to 100 changes.</summary>
    [HttpPost("devices/{id:guid}/sync")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<AccessSyncResultDto> Sync(Guid id, CancellationToken ct)
    {
        var report = await sync.SyncAsync(id, retryFailed: true, ct);
        return new AccessSyncResultDto(report, await DtoAsync(id, ct));
    }

    /// <summary>Clients the device refused: rejected photos and failures being retried.</summary>
    [HttpGet("devices/{id:guid}/issues")]
    [Authorize(Policy = Permissions.ManageIntegrations)]
    public async Task<List<AccessIssueDto>> Issues(Guid id, CancellationToken ct)
    {
        if (!await db.AccessDevices.AnyAsync(d => d.Id == id, ct)) throw ApiException.NotFound("Device");
        return await db.AccessDeviceUsers.Where(u => u.AccessDeviceId == id && (u.State == AccessSyncState.Failed || u.State == AccessSyncState.PhotoRejected))
            .OrderByDescending(u => u.FailedAttempts).ThenBy(u => u.EmployeeNo).Take(100)
            .Select(u => new AccessIssueDto(u.ClientProfileId, u.ClientProfile.User.FirstName + " " + u.ClientProfile.User.LastName,
                u.EmployeeNo, u.State, u.LastError, u.FailedAttempts, u.RetryAt))
            .ToListAsync(ct);
    }

    /// <summary>Passes and refusals reported by the terminals, newest first.</summary>
    [HttpGet("events")]
    public Task<PagedResult<AccessEventDto>> Events([FromQuery] PageQuery paging, [FromQuery] Guid? deviceId, [FromQuery] Guid? clientId,
        CancellationToken ct)
    {
        var q = db.AccessEvents.AsQueryable();
        if (deviceId is not null) q = q.Where(e => e.AccessDeviceId == deviceId);
        if (clientId is not null) q = q.Where(e => e.ClientProfileId == clientId);
        return q.OrderByDescending(e => e.OccurredAt).ThenBy(e => e.Id)
            .Select(e => new AccessEventDto(e.Id, e.OccurredAt, e.AccessDeviceId, e.DeviceName, e.Granted, e.Minor, e.EmployeeNo,
                e.ClientProfile == null ? null : new PersonRef(e.ClientProfile.Id, e.ClientProfile.User.FirstName, e.ClientProfile.User.LastName),
                e.VisitId, e.Note))
            .ToPagedAsync(paging, ct);
    }

    private static void Apply(AccessDevice device, SaveAccessDeviceRequest req)
    {
        device.IsActive = req.IsActive;
        device.RecordsVisits = req.RecordsVisits;
        device.DoorNo = req.DoorNo;
    }

    private string Protect(Guid deviceId, string password)
    {
        if (!protector.IsConfigured)
            throw new ApiException(StatusCodes.Status409Conflict, "encryption_not_configured",
                "The device password cannot be saved: the server encryption key is not configured.");
        return protector.Protect(password, AccessSyncService.PasswordContext(deviceId));
    }

    /// <summary>
    /// <c>192.168.1.64</c> → <c>http://192.168.1.64</c>. Only scheme, host and port are kept; HTTP is the default, as the
    /// terminals ship with self-signed certificates.
    /// </summary>
    public static string NormalizeAddress(string raw)
    {
        var text = raw.Trim();
        if (!text.Contains("://")) text = "http://" + text;
        if (!Uri.TryCreate(text, UriKind.Absolute, out var uri) || uri.Scheme is not ("http" or "https") || string.IsNullOrEmpty(uri.Host)
            || uri.AbsolutePath != "/" || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.UserInfo))
            throw ApiException.BadRequest("invalid_device_address", "Enter the IP address or host of the device, e.g. 192.168.1.64.");
        return uri.GetLeftPart(UriPartial.Authority);
    }

    private void Audit(string action, AccessDevice device, string details) =>
        db.AuditLog.Add(new AuditLogEntry { UserId = currentUser.Id, Action = action, Target = $"access-device:{device.Id}", Details = details });

    private async Task<AccessDeviceDto> DtoAsync(Guid id, CancellationToken ct)
    {
        var device = await db.AccessDevices.AsNoTracking().SingleOrDefaultAsync(d => d.Id == id, ct) ?? throw ApiException.NotFound("Device");
        return (await ToDtosAsync([device], ct)).Single();
    }

    private async Task<List<AccessDeviceDto>> ToDtosAsync(List<AccessDevice> devices, CancellationToken ct)
    {
        var ids = devices.Select(d => d.Id).ToList();
        var plan = (await planner.PlanAsync(null, ct)).Where(p => p.Window is not null).ToDictionary(p => p.ClientId);
        var rows = await db.AccessDeviceUsers.AsNoTracking().Where(u => ids.Contains(u.AccessDeviceId)).ToListAsync(ct);
        return devices.Select(d =>
        {
            var mine = rows.Where(r => r.AccessDeviceId == d.Id).ToDictionary(r => r.ClientProfileId);
            int synced = 0, pending = 0, failed = 0, rejected = 0;
            foreach (var p in plan.Values)
            {
                var row = mine.GetValueOrDefault(p.ClientId);
                if (row is null) pending++;
                else if (row.State == AccessSyncState.PhotoRejected && row.RejectedFaceVersion == p.FaceVersion) rejected++;
                else if (row.State == AccessSyncState.Synced && row.AccessKey == p.AccessKey && row.FaceVersion == p.FaceVersion) synced++;
                else if (row.State == AccessSyncState.Failed) failed++;
                else pending++;
            }
            foreach (var row in mine.Values.Where(r => !plan.ContainsKey(r.ClientProfileId)))
            {
                if (row.State == AccessSyncState.Failed) failed++;
                else pending++;
            }
            return new AccessDeviceDto(d.Id, d.Name, d.BaseUrl, d.Username, d.PasswordCiphertext is not null, d.IsActive, d.RecordsVisits, d.DoorNo,
                EventPath(d.EventToken), d.Model, d.SerialNumber, d.Firmware, d.LastContactAt, d.LastEventAt, d.LastError, d.LastErrorAt,
                new AccessDeviceStatsDto(plan.Count, synced, pending, failed, rejected), protector.IsConfigured);
        }).ToList();
    }

    private static string? Cut(string? value) => value is null ? null : value.Length <= 64 ? value : value[..64];

    private static string Base64Url(byte[] data) => Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
