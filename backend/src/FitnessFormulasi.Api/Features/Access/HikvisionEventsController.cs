using System.Globalization;
using System.Text.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Access;

/// <summary>An access control event from the terminal's HTTP notifications (ISAPI <c>AccessControllerEvent</c>).</summary>
public sealed partial record TerminalEvent(string EventType, string? Time, int Major, int Minor, string? EmployeeNo, long? SerialNo)
{
    /// <summary>Major type 5: an access event (as opposed to alarms, exceptions and operations).</summary>
    public const int MajorEvent = 5;

    /// <summary>Entry granted: valid card (1), fingerprint matched (38), face authentication passed (75).</summary>
    public static readonly IReadOnlySet<int> GrantedMinors = new HashSet<int> { 1, 38, 75 };

    /// <summary>
    /// Refusals of a known person: card not in the validity period (9), face matched but outside the validity period or
    /// failed (76). Refusals without a person (strangers) are not kept.
    /// </summary>
    public static readonly IReadOnlySet<int> DeniedMinors = new HashSet<int> { 9, 76 };

    public bool IsAccess => EventType == "AccessControllerEvent" && Major == MajorEvent;
    public bool Granted => GrantedMinors.Contains(Minor);

    /// <summary>Reads the JSON a terminal posts. Unknown or malformed content gives null.</summary>
    public static TerminalEvent? Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return null;
            var type = Str(root, "eventType") ?? "";
            var time = Str(root, "dateTime");
            if (!root.TryGetProperty("AccessControllerEvent", out var e) || e.ValueKind != JsonValueKind.Object)
                return new TerminalEvent(type, time, 0, 0, null, null);
            var employee = Str(e, "employeeNoString") ?? Str(e, "employeeNo");
            return new TerminalEvent(type, time, Int(e, "majorEventType") ?? 0, Int(e, "subEventType") ?? 0,
                string.IsNullOrWhiteSpace(employee) ? null : employee.Trim(), Long(e, "serialNo"));
        }
        catch (JsonException) { return null; }
    }

    /// <summary>
    /// Event time. Terminals send it with the UTC offset; a time without one is taken as club-local time.
    /// </summary>
    public DateTimeOffset? OccurredAt(TimeZoneInfo club)
    {
        if (Time is null) return null;
        if (WithOffset().IsMatch(Time))
            return DateTimeOffset.TryParse(Time, CultureInfo.InvariantCulture, DateTimeStyles.None, out var o) ? o : null;
        return DateTime.TryParse(Time, CultureInfo.InvariantCulture, DateTimeStyles.None, out var local)
            ? new DateTimeOffset(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), club.GetUtcOffset(local))
            : null;
    }

    [System.Text.RegularExpressions.GeneratedRegex(@"(Z|[+-]\d{2}:?\d{2})$")]
    private static partial System.Text.RegularExpressions.Regex WithOffset();

    private static string? Str(JsonElement e, string name) => e.TryGetProperty(name, out var v)
        ? v.ValueKind switch { JsonValueKind.String => v.GetString(), JsonValueKind.Number => v.GetRawText(), _ => null }
        : null;

    private static int? Int(JsonElement e, string name) => long.TryParse(Str(e, name), out var v) ? (int)v : null;
    private static long? Long(JsonElement e, string name) => long.TryParse(Str(e, name), out var v) ? v : null;
}

/// <summary>
/// Receives events the terminals push (Configuration → Network → Advanced → HTTP Listening on the device). The device
/// cannot authenticate, so the URL carries a random per-device token. Always answers 200 for a known device, otherwise
/// the device keeps resending the same event.
/// </summary>
[ApiController]
[Route("api/access/hikvision")]
[AllowAnonymous]
public class HikvisionEventsController(AppDbContext db, IClubClock clock, CheckInService checkIn, ILogger<HikvisionEventsController> logger)
    : ControllerBase
{
    /// <summary>Events larger than this (several pictures) are not expected from an access terminal.</summary>
    public const int MaxEventBytes = 4 * 1024 * 1024;

    [HttpPost("events/{token}")]
    [RequestSizeLimit(MaxEventBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = MaxEventBytes)]
    public async Task<IActionResult> Receive(string token, CancellationToken ct)
    {
        var device = await db.AccessDevices.SingleOrDefaultAsync(d => d.EventToken == token, ct);
        if (device is null || !device.IsActive) return NotFound();
        device.LastEventAt = clock.UtcNow;

        foreach (var json in await JsonPartsAsync(ct))
        {
            var e = TerminalEvent.Parse(json);
            if (e is null || !e.IsAccess || e.EmployeeNo is null) continue;
            if (!e.Granted && !TerminalEvent.DeniedMinors.Contains(e.Minor)) continue;
            await RecordAsync(device, e, ct);
        }
        await db.SaveChangesAsync(ct);
        return Ok();
    }

    private async Task RecordAsync(AccessDevice device, TerminalEvent e, CancellationToken ct)
    {
        if (e.SerialNo is { } serial && await db.AccessEvents.AnyAsync(x => x.AccessDeviceId == device.Id && x.SerialNo == serial, ct))
            return; // delivered again

        var now = clock.UtcNow;
        // The terminal's own time, unless its clock is clearly off.
        var at = e.OccurredAt(clock.TimeZone) is { } t && t <= now.AddMinutes(5) && t >= now.AddDays(-1) ? t.ToUniversalTime() : now;
        Guid? clientId = int.TryParse(e.EmployeeNo, NumberStyles.None, CultureInfo.InvariantCulture, out var no)
            ? await db.ClientProfiles.Where(c => c.AccessNo == no).Select(c => (Guid?)c.Id).SingleOrDefaultAsync(ct)
            : null;

        var entry = new AccessEvent
        {
            AccessDeviceId = device.Id, DeviceName = device.Name, SerialNo = e.SerialNo, OccurredAt = at, Major = e.Major, Minor = e.Minor,
            Granted = e.Granted, EmployeeNo = e.EmployeeNo, ClientProfileId = clientId,
        };
        if (e.Granted && clientId is { } id)
        {
            if (device.RecordsVisits)
            {
                var (visitId, denial) = await checkIn.RecordTerminalPassAsync(id, at, ct);
                entry.VisitId = visitId;
                entry.Note = denial;
            }
        }
        else if (e.Granted)
        {
            entry.Note = "unknown_person";
        }
        db.AccessEvents.Add(entry);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException) when (e.SerialNo is not null)
        {
            // The same event arrived twice at once; the other request recorded it.
            db.Entry(entry).State = EntityState.Detached;
        }
        if (entry.Note is not null and not "unknown_person")
            logger.LogWarning("Terminal {Device} let client {ClientId} in without a valid membership ({Reason})", device.Name, clientId, entry.Note);
    }

    /// <summary>
    /// Terminals post the event as JSON, or as multipart with the JSON in a part (usually <c>event_log</c>) and the
    /// captured picture in another.
    /// </summary>
    private async Task<List<string>> JsonPartsAsync(CancellationToken ct)
    {
        if (Request.HasFormContentType)
        {
            var form = await Request.ReadFormAsync(ct);
            var parts = form.SelectMany(f => f.Value).Where(v => v is not null && v.TrimStart().StartsWith('{')).Select(v => v!).ToList();
            foreach (var file in form.Files.Where(f => f.ContentType.Contains("json", StringComparison.OrdinalIgnoreCase) && f.Length < 256 * 1024))
            {
                using var reader = new StreamReader(file.OpenReadStream());
                parts.Add(await reader.ReadToEndAsync(ct));
            }
            return parts;
        }
        using var body = new StreamReader(Request.Body);
        var text = await body.ReadToEndAsync(ct);
        return text.TrimStart().StartsWith('{') ? [text] : [];
    }
}
