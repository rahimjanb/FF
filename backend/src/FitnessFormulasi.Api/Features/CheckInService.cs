using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

public class CheckInRequest
{
    /// <summary>Text read from the client's QR pass by the desk scanner.</summary>
    [Required, StringLength(128)] public string Code { get; set; } = "";
}

/// <summary>Why entry was refused; stable codes for the admin panel.</summary>
public static class CheckInDenials
{
    public const string InvalidCode = "invalid_code";
    public const string ExpiredCode = "expired_code";
    public const string ClientBlocked = "client_blocked";
    public const string NoMembership = "no_membership";
    public const string MembershipExpired = "membership_expired";
    public const string MembershipUpcoming = "membership_upcoming";
    public const string MembershipFrozen = "membership_frozen";
    public const string VisitLimitReached = "visit_limit_reached";
}

public record CheckInClientDto(Guid Id, string FirstName, string LastName, string Phone, PersonRef? AssignedTrainer);

/// <summary>
/// Decision for one scan. Allowed: the visit is recorded (or, for a repeated scan within a couple of minutes,
/// the visit already recorded is returned). Refused: <see cref="Reason"/> says why and nothing is recorded.
/// </summary>
public record CheckInResultDto(
    bool Allowed, string? Reason, bool Repeated, CheckInClientDto? Client, MembershipDto? Membership, VisitDto? Visit,
    int VisitsToday, DateTimeOffset? PreviousVisitAt);

public sealed class CheckInService(
    AppDbContext db, IClubClock clock, ICurrentUser currentUser, PassTokenService passes, MembershipService memberships)
{
    /// <summary>A second scan of the same client within this window returns the same visit instead of a new one.</summary>
    public static readonly TimeSpan RepeatWindow = TimeSpan.FromMinutes(2);

    public async Task<CheckInResultDto> CheckInAsync(CheckInRequest req, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var (error, clientId) = passes.Validate(req.Code, now);
        if (error != PassTokenError.None)
            return Denied(error == PassTokenError.Expired ? CheckInDenials.ExpiredCode : CheckInDenials.InvalidCode, null, null);

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Serializes scans of the same client, so a double scan cannot record two visits or pass the visit limit.
        var locked = await db.ClientProfiles.FromSql($"SELECT * FROM \"ClientProfiles\" WHERE \"Id\" = {clientId} FOR UPDATE")
            .AnyAsync(ct);
        if (!locked) return Denied(CheckInDenials.InvalidCode, null, null);

        var client = await db.ClientProfiles.Where(c => c.Id == clientId).Select(c => new
        {
            Dto = new CheckInClientDto(c.Id, c.User.FirstName, c.User.LastName, c.User.Phone,
                c.AssignedTrainer == null ? null
                    : new PersonRef(c.AssignedTrainer.Id, c.AssignedTrainer.User.FirstName, c.AssignedTrainer.User.LastName)),
            c.User.Status,
        }).SingleAsync(ct);
        if (client.Status != UserStatus.Active) return await DeniedWithVisitsAsync(CheckInDenials.ClientBlocked, client.Dto, null, ct);

        var current = await memberships.CurrentForClientAsync(clientId, ct);
        if (current is null)
        {
            if (await memberships.NextForClientAsync(clientId, ct) is { } next)
                return await DeniedWithVisitsAsync(CheckInDenials.MembershipUpcoming, client.Dto, next, ct);
            var last = (await memberships.ForClientAsync(clientId, ct)).FirstOrDefault(m => m.Status != MembershipStatus.Cancelled);
            return last is null
                ? await DeniedWithVisitsAsync(CheckInDenials.NoMembership, client.Dto, null, ct)
                : await DeniedWithVisitsAsync(CheckInDenials.MembershipExpired, client.Dto, last, ct);
        }
        switch (current.EffectiveStatus)
        {
            case MembershipEffectiveStatus.Frozen:
                return await DeniedWithVisitsAsync(CheckInDenials.MembershipFrozen, client.Dto, current, ct);
            case MembershipEffectiveStatus.Exhausted:
                return await DeniedWithVisitsAsync(CheckInDenials.VisitLimitReached, client.Dto, current, ct);
            case not MembershipEffectiveStatus.Active:
                return await DeniedWithVisitsAsync(CheckInDenials.NoMembership, client.Dto, current, ct);
        }

        var since = now - RepeatWindow;
        var recent = await db.Visits.Where(v => v.ClientProfileId == clientId && v.Source == VisitSource.QrScan && v.VisitedAt >= since)
            .OrderByDescending(v => v.VisitedAt).Select(v => (Guid?)v.Id).FirstOrDefaultAsync(ct);
        var visitId = recent;
        if (visitId is null)
        {
            var visit = new Visit
            {
                ClientProfileId = clientId, MembershipId = current.Id, VisitedAt = now, Source = VisitSource.QrScan,
                RecordedByUserId = currentUser.Id,
            };
            db.Visits.Add(visit);
            await db.SaveChangesAsync(ct);
            visitId = visit.Id;
        }
        await tx.CommitAsync(ct);

        var dto = await db.Visits.Where(v => v.Id == visitId).Select(Projections.VisitExpr).SingleAsync(ct);
        var (today, previous) = await VisitCountsAsync(clientId, dto.Id, ct);
        return new CheckInResultDto(true, null, recent is not null, client.Dto, await memberships.GetAsync(current.Id, ct), dto,
            today, previous);
    }

    /// <summary>
    /// Records a visit for a pass through the face terminal at <paramref name="at"/>. The terminal has already let the
    /// client in by the validity period it holds; the visit is linked to the membership valid that day. Returns why no
    /// visit was recorded if the terminal was out of date (the pass shows up in the journal with that reason).
    /// A pass within <see cref="RepeatWindow"/> of a previous QR or terminal visit is the same visit.
    /// </summary>
    public async Task<(Guid? VisitId, string? Denial)> RecordTerminalPassAsync(Guid clientId, DateTimeOffset at, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var locked = await db.ClientProfiles.FromSql($"SELECT * FROM \"ClientProfiles\" WHERE \"Id\" = {clientId} FOR UPDATE")
            .AnyAsync(ct);
        if (!locked) return (null, CheckInDenials.InvalidCode);
        if (await db.ClientProfiles.AnyAsync(c => c.Id == clientId && c.User.Status != UserStatus.Active, ct))
            return (null, CheckInDenials.ClientBlocked);

        var day = clock.ToClubDate(at);
        var rows = await db.Memberships
            .Where(m => m.ClientProfileId == clientId && m.Status != MembershipStatus.Cancelled && m.StartDate <= day && m.EndDate >= day)
            .Select(Projections.MembershipRowExpr).ToListAsync(ct);
        var memberships = rows.Select(r => r.ToDto(day)).ToList();
        var current = memberships.FirstOrDefault(m => m.EffectiveStatus == MembershipEffectiveStatus.Active);
        if (current is null)
        {
            var reason = memberships.Any(m => m.EffectiveStatus == MembershipEffectiveStatus.Frozen) ? CheckInDenials.MembershipFrozen
                : memberships.Any(m => m.EffectiveStatus == MembershipEffectiveStatus.Exhausted) ? CheckInDenials.VisitLimitReached
                : CheckInDenials.NoMembership;
            return (null, reason);
        }

        var since = at - RepeatWindow;
        var recent = await db.Visits
            .Where(v => v.ClientProfileId == clientId && (v.Source == VisitSource.QrScan || v.Source == VisitSource.FaceTerminal)
                        && v.VisitedAt >= since && v.VisitedAt <= at + RepeatWindow)
            .Select(v => (Guid?)v.Id).FirstOrDefaultAsync(ct);
        if (recent is not null) return (recent, null);

        var visit = new Visit { ClientProfileId = clientId, MembershipId = current.Id, VisitedAt = at, Source = VisitSource.FaceTerminal };
        db.Visits.Add(visit);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return (visit.Id, null);
    }

    private static CheckInResultDto Denied(string reason, CheckInClientDto? client, MembershipDto? membership) =>
        new(false, reason, false, client, membership, null, 0, null);

    private async Task<CheckInResultDto> DeniedWithVisitsAsync(
        string reason, CheckInClientDto client, MembershipDto? membership, CancellationToken ct)
    {
        var (today, previous) = await VisitCountsAsync(client.Id, null, ct);
        return new CheckInResultDto(false, reason, false, client, membership, null, today, previous);
    }

    /// <summary>Visits since the start of the club day, and the last visit before <paramref name="exceptId"/>.</summary>
    private async Task<(int Today, DateTimeOffset? Previous)> VisitCountsAsync(Guid clientId, Guid? exceptId, CancellationToken ct)
    {
        var dayStart = clock.StartOfDayUtc(clock.Today);
        var visits = db.Visits.Where(v => v.ClientProfileId == clientId);
        var today = await visits.CountAsync(v => v.VisitedAt >= dayStart, ct);
        var previous = await visits.Where(v => v.Id != exceptId).MaxAsync(v => (DateTimeOffset?)v.VisitedAt, ct);
        return (today, previous);
    }
}
