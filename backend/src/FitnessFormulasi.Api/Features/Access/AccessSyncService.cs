using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Integrations;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Access;

public sealed record AccessSyncReport(int Written, int FacesUploaded, int Removed, int Failed, int Remaining, string? DeviceError);

/// <summary>
/// Brings one terminal in line with the memberships: every client with a face photo and days to enter is on it with
/// those days as the validity period; everyone else is removed. Works from the difference between the plan and what
/// the terminal confirmed last time, so a pass that stops halfway is simply continued by the next one.
/// </summary>
public sealed class AccessSyncService(
    AppDbContext db, IClubClock clock, AccessPlanner planner, HikvisionTerminalFactory terminals, SecretProtector protector,
    AccessSyncLock gate, ILogger<AccessSyncService> logger)
{
    /// <summary>Changes per pass; the rest is picked up by the next pass a minute later.</summary>
    public const int MaxOperationsPerPass = 100;
    /// <summary>A device not contacted for this long is pinged, so the admin panel shows whether it is reachable.</summary>
    public static readonly TimeSpan PingInterval = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan[] Backoff =
        [TimeSpan.FromMinutes(1), TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(15), TimeSpan.FromHours(1)];

    public static string PasswordContext(Guid deviceId) => $"AccessDevice/{deviceId}/password";

    public async Task SyncAllAsync(CancellationToken ct)
    {
        var ids = await db.AccessDevices.Where(d => d.IsActive).Select(d => d.Id).ToListAsync(ct);
        foreach (var id in ids)
        {
            try { await SyncAsync(id, retryFailed: false, ct); }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                logger.LogError(e, "Access sync of device {DeviceId} failed", id);
            }
        }
    }

    /// <summary>One pass over one device. <paramref name="retryFailed"/>: retry clients that failed recently instead of waiting for their back-off.</summary>
    public async Task<AccessSyncReport> SyncAsync(Guid deviceId, bool retryFailed, CancellationToken ct)
    {
        await gate.WaitAsync(ct);
        try { return await RunAsync(deviceId, retryFailed, ct); }
        finally { gate.Release(); }
    }

    private async Task<AccessSyncReport> RunAsync(Guid deviceId, bool retryFailed, CancellationToken ct)
    {
        var device = await db.AccessDevices.SingleOrDefaultAsync(d => d.Id == deviceId, ct) ?? throw ApiException.NotFound("Device");
        if (!device.IsActive) throw ApiException.Conflict("device_inactive", "The device is switched off.");
        var now = clock.UtcNow;

        var password = device.PasswordCiphertext is null ? null : protector.Unprotect(device.PasswordCiphertext, PasswordContext(device.Id));
        if (password is null)
            return await DeviceFailedAsync(device, "The device password is not set or cannot be decrypted; enter it again.", 0, 0, 0, 0, 0, ct);

        var plan = await planner.PlanAsync(null, ct);
        var rows = await db.AccessDeviceUsers.Where(u => u.AccessDeviceId == deviceId).ToDictionaryAsync(u => u.ClientProfileId, ct);
        var work = Diff(plan, rows, retryFailed, now);

        using var terminal = terminals.Create(device.BaseUrl, device.Username, password);
        int written = 0, faces = 0, removed = 0, failed = 0, done = 0;
        foreach (var item in work)
        {
            if (done == MaxOperationsPerPass) break;
            done++;
            try
            {
                if (item.Plan?.Window is not { } window)
                {
                    await terminal.DeleteUserAsync(item.Row!.EmployeeNo, ct);
                    db.AccessDeviceUsers.Remove(item.Row);
                    removed++;
                }
                else
                {
                    var p = item.Plan;
                    var row = item.Row ?? AddRow(device.Id, p);
                    if (row.AccessKey != p.AccessKey)
                    {
                        await terminal.UpsertUserAsync(new TerminalUser(p.EmployeeNo, p.Name, window.From, window.To, device.DoorNo), ct);
                        row.AccessKey = p.AccessKey;
                        written++;
                    }
                    if (row.FaceVersion != p.FaceVersion && row.RejectedFaceVersion != p.FaceVersion)
                    {
                        var jpeg = await db.ClientFaces.Where(f => f.ClientProfileId == p.ClientId).Select(f => f.Data).SingleAsync(ct);
                        try
                        {
                            await terminal.SetFaceAsync(p.EmployeeNo, jpeg, ct);
                            row.FaceVersion = p.FaceVersion;
                            faces++;
                        }
                        catch (IsapiException e) when (e.Failure == IsapiFailure.Rejected)
                        {
                            // The photo itself is the problem: wait for a new one instead of retrying.
                            row.RejectedFaceVersion = p.FaceVersion;
                            row.State = AccessSyncState.PhotoRejected;
                            row.LastError = Trim(e.Message);
                            failed++;
                            device.LastContactAt = clock.UtcNow;
                            await db.SaveChangesAsync(ct);
                            continue;
                        }
                    }
                    row.State = row.RejectedFaceVersion == p.FaceVersion ? AccessSyncState.PhotoRejected : AccessSyncState.Synced;
                    if (row.State == AccessSyncState.Synced) row.LastError = null;
                    row.FailedAttempts = 0;
                    row.RetryAt = null;
                    row.SyncedAt = now;
                }
                device.LastContactAt = clock.UtcNow;
                await db.SaveChangesAsync(ct);
            }
            catch (IsapiException e) when (e.Failure == IsapiFailure.Rejected)
            {
                failed++;
                MarkFailed(item, device.Id, e.Message, now);
                await db.SaveChangesAsync(ct);
            }
            catch (IsapiException e)
            {
                // The device cannot be reached or does not accept the login: no point going on with the others.
                // What was confirmed so far is kept; the next pass continues from there.
                return await DeviceFailedAsync(device, e.Message, written, faces, removed, failed, work.Count - done + 1, ct);
            }
        }

        if (done == 0 && (device.LastContactAt is null || now - device.LastContactAt > PingInterval))
        {
            try
            {
                await terminal.GetInfoAsync(ct);
                device.LastContactAt = clock.UtcNow;
            }
            catch (IsapiException e)
            {
                return await DeviceFailedAsync(device, e.Message, 0, 0, 0, 0, 0, ct);
            }
        }
        device.LastError = null;
        device.LastErrorAt = null;
        await db.SaveChangesAsync(ct);
        if (done > 0)
            logger.LogInformation("Access device {DeviceId}: {Written} written, {Faces} faces, {Removed} removed, {Failed} failed",
                device.Id, written, faces, removed, failed);
        return new AccessSyncReport(written, faces, removed, failed, work.Count - done, null);
    }

    private sealed record WorkItem(PlannedClient? Plan, AccessDeviceUser? Row);

    /// <summary>Removals first, to free room on the terminal; then people missing or out of date.</summary>
    private static List<WorkItem> Diff(List<PlannedClient> plan, Dictionary<Guid, AccessDeviceUser> rows, bool retryFailed, DateTimeOffset now)
    {
        bool Due(AccessDeviceUser? r) => r is null || retryFailed || r.RetryAt is null || r.RetryAt <= now;
        var planned = plan.ToDictionary(p => p.ClientId);
        var removals = rows.Values
            .Where(r => (!planned.TryGetValue(r.ClientProfileId, out var p) || p.Window is null) && Due(r))
            .Select(r => new WorkItem(null, r));
        var updates = plan
            .Where(p => p.Window is not null)
            .Select(p => new WorkItem(p, rows.GetValueOrDefault(p.ClientId)))
            .Where(w => (w.Row is null || w.Row.AccessKey != w.Plan!.AccessKey
                         || (w.Row.FaceVersion != w.Plan.FaceVersion && w.Row.RejectedFaceVersion != w.Plan.FaceVersion))
                        && Due(w.Row));
        return [.. removals, .. updates];
    }

    private AccessDeviceUser AddRow(Guid deviceId, PlannedClient p)
    {
        var row = new AccessDeviceUser { AccessDeviceId = deviceId, ClientProfileId = p.ClientId, EmployeeNo = p.EmployeeNo };
        db.AccessDeviceUsers.Add(row);
        return row;
    }

    private void MarkFailed(WorkItem item, Guid deviceId, string error, DateTimeOffset now)
    {
        var row = item.Row ?? db.ChangeTracker.Entries<AccessDeviceUser>()
            .Select(e => e.Entity).FirstOrDefault(r => r.AccessDeviceId == deviceId && r.ClientProfileId == item.Plan!.ClientId);
        if (row is null) return;
        row.State = AccessSyncState.Failed;
        row.LastError = Trim(error);
        row.RetryAt = now + Backoff[Math.Min(row.FailedAttempts, Backoff.Length - 1)];
        row.FailedAttempts++;
    }

    private async Task<AccessSyncReport> DeviceFailedAsync(
        AccessDevice device, string error, int written, int faces, int removed, int failed, int remaining, CancellationToken ct)
    {
        device.LastError = Trim(error);
        device.LastErrorAt = clock.UtcNow;
        await db.SaveChangesAsync(ct);
        logger.LogWarning("Access device {DeviceId} ({Name}) failed: {Error}", device.Id, device.Name, device.LastError);
        return new AccessSyncReport(written, faces, removed, failed, remaining, device.LastError);
    }

    private static string Trim(string text) => text.Length <= 500 ? text : text[..500];
}

/// <summary>One synchronisation at a time per process: the background worker and "sync now" in the admin panel.</summary>
public sealed class AccessSyncLock
{
    private readonly SemaphoreSlim _semaphore = new(1, 1);
    public Task WaitAsync(CancellationToken ct) => _semaphore.WaitAsync(ct);
    public void Release() => _semaphore.Release();
}
