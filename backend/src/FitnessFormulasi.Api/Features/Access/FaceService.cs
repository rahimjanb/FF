using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Access;

/// <summary>
/// None: no photo. Waiting: the photo is saved but not on the terminals: no membership to enter with
/// (<see cref="FaceAccessDto.HasAccess"/> false) or no terminal connected yet. Pending: being sent to the terminals.
/// Ready: on every terminal, entry by face works. Rejected: a terminal found no face in the photo; take a new one.
/// </summary>
public enum FaceAccessStatus { None, Waiting, Pending, Ready, Rejected }

/// <summary>Face entry state as the client sees it. <see cref="AccessFrom"/>/<see cref="AccessTo"/>: days the terminal lets them in.</summary>
public record FaceAccessDto(
    FaceAccessStatus Status, int Version, DateTimeOffset? UploadedAt, bool HasAccess, DateOnly? AccessFrom, DateOnly? AccessTo, int Terminals);

public record FaceDeviceStateDto(Guid DeviceId, string DeviceName, AccessSyncState State, string? LastError, DateTimeOffset? SyncedAt);

/// <summary>For staff: also who uploaded, when consent was given, and the state on each terminal with the device's answer.</summary>
public record FaceAccessAdminDto(
    FaceAccessStatus Status, int Version, DateTimeOffset? UploadedAt, bool HasAccess, DateOnly? AccessFrom, DateOnly? AccessTo, int Terminals,
    int? AccessNo, DateTimeOffset? ConsentAt, string? UploadedBy, List<FaceDeviceStateDto> Devices);

public sealed class FaceService(AppDbContext db, IClubClock clock, ICurrentUser currentUser, AccessPlanner planner)
{
    /// <summary>Hikvision terminals accept face photos of up to 200 KB.</summary>
    public const int MaxFaceBytes = 200 * 1024;
    /// <summary>A smaller photo does not carry enough detail for the face model.</summary>
    public const int MinFaceSide = 240;
    public const int MaxFaceSide = 4096;

    public async Task<FaceAccessDto> StatusAsync(Guid clientId, CancellationToken ct)
    {
        var s = await AdminStatusAsync(clientId, ct);
        return new FaceAccessDto(s.Status, s.Version, s.UploadedAt, s.HasAccess, s.AccessFrom, s.AccessTo, s.Terminals);
    }

    public async Task<FaceAccessAdminDto> AdminStatusAsync(Guid clientId, CancellationToken ct)
    {
        var face = await db.ClientFaces.AsNoTracking().Where(f => f.ClientProfileId == clientId)
            .Select(f => new
            {
                f.Version, f.UploadedAt, f.ConsentAt, f.ClientProfile.AccessNo,
                UploadedBy = db.Users.Where(u => u.Id == f.UploadedByUserId).Select(u => u.FirstName + " " + u.LastName).FirstOrDefault(),
            })
            .SingleOrDefaultAsync(ct);
        var devices = await db.AccessDevices.AsNoTracking().Where(d => d.IsActive).OrderBy(d => d.Name)
            .Select(d => new { d.Id, d.Name }).ToListAsync(ct);
        if (face is null) return new FaceAccessAdminDto(FaceAccessStatus.None, 0, null, false, null, null, devices.Count, null, null, null, []);

        var plan = (await planner.PlanAsync(clientId, ct)).SingleOrDefault();
        var rows = await db.AccessDeviceUsers.AsNoTracking().Where(u => u.ClientProfileId == clientId).ToListAsync(ct);
        var states = devices.Select(d =>
        {
            var row = rows.FirstOrDefault(r => r.AccessDeviceId == d.Id);
            var upToDate = row is not null && row.State == AccessSyncState.Synced && row.AccessKey == plan?.AccessKey && row.FaceVersion == face.Version;
            var state = row is null ? AccessSyncState.Pending
                : row.State == AccessSyncState.PhotoRejected && row.RejectedFaceVersion == face.Version ? AccessSyncState.PhotoRejected
                : upToDate ? AccessSyncState.Synced
                : row.State == AccessSyncState.Failed ? AccessSyncState.Failed
                : AccessSyncState.Pending;
            return new FaceDeviceStateDto(d.Id, d.Name, state, state == AccessSyncState.Synced ? null : row?.LastError, row?.SyncedAt);
        }).ToList();

        var window = plan?.Window;
        var status = states.Any(s => s.State == AccessSyncState.PhotoRejected) ? FaceAccessStatus.Rejected
            : window is null || devices.Count == 0 ? FaceAccessStatus.Waiting
            : states.All(s => s.State == AccessSyncState.Synced) ? FaceAccessStatus.Ready
            : FaceAccessStatus.Pending;
        return new FaceAccessAdminDto(status, face.Version, face.UploadedAt, window is not null, window?.From, window?.To, devices.Count,
            face.AccessNo, face.ConsentAt, face.UploadedBy, states);
    }

    /// <summary>
    /// Saves the client's face photo (JPEG, 240 px and more on the short side, up to 200 KB) with the consent given
    /// for it. The terminals receive it with the next synchronisation, a few seconds later.
    /// </summary>
    public async Task UploadAsync(Guid clientId, IFormFile? file, bool consent, CancellationToken ct)
    {
        if (!consent)
            throw ApiException.BadRequest("face_consent_required", "Consent to processing the face photo is required.");
        if (file is null || file.Length == 0)
            throw ApiException.BadRequest("face_invalid_format", "Attach a JPEG photo.");
        if (file.Length > MaxFaceBytes)
            throw ApiException.BadRequest("face_too_large", "The photo must be a JPEG of up to 200 KB.");
        using var buffer = new MemoryStream();
        await file.CopyToAsync(buffer, ct);
        var data = buffer.ToArray();
        if (JpegSize(data) is not { } size)
            throw ApiException.BadRequest("face_invalid_format", "Only JPEG photos are accepted.");
        if (Math.Min(size.Width, size.Height) < MinFaceSide || Math.Max(size.Width, size.Height) > MaxFaceSide)
            throw ApiException.BadRequest("face_bad_size", $"The photo must be from {MinFaceSide} to {MaxFaceSide} pixels on each side.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var client = await db.ClientProfiles.FromSql($"SELECT * FROM \"ClientProfiles\" WHERE \"Id\" = {clientId} FOR UPDATE")
                         .SingleOrDefaultAsync(ct) ?? throw ApiException.NotFound("Client");
        if (await db.Users.AnyAsync(u => u.Id == client.UserId && u.Status == UserStatus.Deleted, ct))
            throw ApiException.Conflict("client_deleted", "The client's account has been deleted.");
        client.AccessNo ??= await db.Database
            .SqlQuery<int>($"SELECT nextval('\"ClientAccessNumbers\"')::int AS \"Value\"").SingleAsync(ct);

        var now = clock.UtcNow;
        var face = await db.ClientFaces.SingleOrDefaultAsync(f => f.ClientProfileId == clientId, ct);
        if (face is null)
        {
            // After a deleted photo, versions continue above anything a terminal still holds, so a terminal that missed
            // the deletion (offline) does not take the new photo for the old one.
            var seen = await db.AccessDeviceUsers.Where(u => u.ClientProfileId == clientId)
                .MaxAsync(u => (int?)(u.FaceVersion > (u.RejectedFaceVersion ?? 0) ? u.FaceVersion : u.RejectedFaceVersion ?? 0), ct) ?? 0;
            face = new ClientFace { ClientProfileId = clientId, Data = data, Version = seen + 1 };
            db.ClientFaces.Add(face);
        }
        else
        {
            face.Data = data;
            face.Version++;
        }
        face.UploadedAt = now;
        face.ConsentAt = now;
        face.UploadedByUserId = currentUser.Id;
        Audit(clientId, "face.uploaded", client.UserId == currentUser.Id ? "by the client in the app" : "by staff");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    /// <summary>Deletes the photo; the next synchronisation removes the client from the terminals.</summary>
    public async Task DeleteAsync(Guid clientId, CancellationToken ct)
    {
        var face = await db.ClientFaces.Include(f => f.ClientProfile).SingleOrDefaultAsync(f => f.ClientProfileId == clientId, ct);
        if (face is null) return;
        db.ClientFaces.Remove(face);
        Audit(clientId, "face.deleted", face.ClientProfile.UserId == currentUser.Id ? "by the client in the app" : "by staff");
        await db.SaveChangesAsync(ct);
    }

    public async Task<byte[]?> PhotoAsync(Guid clientId, CancellationToken ct) =>
        await db.ClientFaces.Where(f => f.ClientProfileId == clientId).Select(f => f.Data).SingleOrDefaultAsync(ct);

    private void Audit(Guid clientId, string action, string details) =>
        db.AuditLog.Add(new AuditLogEntry { UserId = currentUser.Id, Action = action, Target = $"client:{clientId}", Details = details });

    /// <summary>Width and height from the JPEG frame header, or null if the data is not a JPEG image.</summary>
    public static (int Width, int Height)? JpegSize(ReadOnlySpan<byte> d)
    {
        if (d.Length < 4 || d[0] != 0xFF || d[1] != 0xD8) return null;
        var i = 2;
        while (i + 3 < d.Length)
        {
            if (d[i] != 0xFF) return null;
            var marker = d[i + 1];
            if (marker == 0xFF) { i++; continue; } // fill byte
            if (marker is 0x01 or (>= 0xD0 and <= 0xD7)) { i += 2; continue; } // markers without a length
            if (marker is 0xD9 or 0xDA) return null; // end of image or scan data before a frame header
            var length = (d[i + 2] << 8) | d[i + 3];
            if (length < 2) return null;
            // SOF0..SOF15, except DHT (C4), JPG (C8) and DAC (CC).
            if (marker is >= 0xC0 and <= 0xCF and not 0xC4 and not 0xC8 and not 0xCC)
            {
                if (i + 8 >= d.Length) return null;
                var height = (d[i + 5] << 8) | d[i + 6];
                var width = (d[i + 7] << 8) | d[i + 8];
                return width > 0 && height > 0 ? (width, height) : null;
            }
            i += 2 + length;
        }
        return null;
    }
}
