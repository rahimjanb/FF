using System.Text;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Access;

/// <summary>Days the terminal lets the client in (club-local dates, inclusive).</summary>
public readonly record struct AccessWindow(DateOnly From, DateOnly To);

public sealed record MembershipSpan(
    DateOnly Start, DateOnly End, MembershipStatus Status, int? VisitLimit, int VisitsUsed,
    IReadOnlyList<(DateOnly Start, DateOnly End)> Freezes);

public static class AccessWindowCalculator
{
    /// <summary>
    /// The first run of days, ending today or later, on which the client may enter: membership days without freezes,
    /// joined across back-to-back memberships. A frozen-by-staff, cancelled or used-up membership gives no days.
    /// The terminal checks the dates itself, so an expiring membership or a starting freeze needs no request at midnight;
    /// a visit limit is enforced by the next synchronisation after the last visit.
    /// </summary>
    public static AccessWindow? Compute(IEnumerable<MembershipSpan> memberships, DateOnly today)
    {
        var ranges = new List<(int From, int To)>();
        foreach (var m in memberships)
        {
            if (m.Status != MembershipStatus.Active || m.End < today) continue;
            if (m.VisitLimit is { } limit && m.VisitsUsed >= limit) continue;
            var cursor = m.Start.DayNumber;
            foreach (var f in m.Freezes.OrderBy(f => f.Start))
            {
                if (f.Start.DayNumber > cursor) ranges.Add((cursor, Math.Min(f.Start.DayNumber - 1, m.End.DayNumber)));
                cursor = Math.Max(cursor, f.End.DayNumber + 1);
            }
            if (cursor <= m.End.DayNumber) ranges.Add((cursor, m.End.DayNumber));
        }

        ranges.Sort();
        (int From, int To)? current = null;
        foreach (var r in ranges)
        {
            if (current is { } c && r.From <= c.To + 1)
            {
                current = (c.From, Math.Max(c.To, r.To));
                continue;
            }
            if (current is { } done && done.To >= today.DayNumber) break;
            current = r;
        }
        return current is { } w && w.To >= today.DayNumber
            ? new AccessWindow(DateOnly.FromDayNumber(w.From), DateOnly.FromDayNumber(w.To))
            : null;
    }
}

/// <summary>What the terminals should hold for one client with a face photo. <see cref="Window"/> null: nothing.</summary>
public sealed record PlannedClient(Guid ClientId, string EmployeeNo, string Name, int FaceVersion, AccessWindow? Window)
{
    /// <summary>Name and dates as written to the terminal; a change means the person must be written again.</summary>
    public string? AccessKey => Window is { } w ? $"{w.From:yyyy-MM-dd}/{w.To:yyyy-MM-dd}/{Name}" : null;
}

/// <summary>Works out which clients belong on the terminals and with which dates.</summary>
public sealed class AccessPlanner(AppDbContext db, IClubClock clock)
{
    /// <summary>The terminal shows the name on a pass; longer names are cut at 32 bytes of UTF-8.</summary>
    public const int MaxNameBytes = 32;

    public async Task<List<PlannedClient>> PlanAsync(Guid? clientId, CancellationToken ct)
    {
        var today = clock.Today;
        var rows = await db.ClientFaces.AsNoTracking()
            .Where(f => clientId == null || f.ClientProfileId == clientId)
            .Select(f => new
            {
                f.ClientProfileId,
                f.Version,
                f.ClientProfile.AccessNo,
                f.ClientProfile.User.FirstName,
                f.ClientProfile.User.LastName,
                Blocked = f.ClientProfile.User.Status != UserStatus.Active,
                Memberships = f.ClientProfile.Memberships
                    .Where(m => m.Status == MembershipStatus.Active && m.EndDate >= today)
                    .Select(m => new
                    {
                        m.StartDate, m.EndDate, m.Status, m.VisitLimit,
                        VisitsUsed = m.Visits.Count(),
                        Freezes = m.Freezes.Select(x => new { x.StartDate, x.EndDate }).ToList(),
                    }).ToList(),
            })
            .AsSplitQuery()
            .ToListAsync(ct);

        return rows.Where(r => r.AccessNo is not null).Select(r =>
        {
            var spans = r.Memberships.Select(m => new MembershipSpan(m.StartDate, m.EndDate, m.Status, m.VisitLimit, m.VisitsUsed,
                m.Freezes.Select(x => (x.StartDate, x.EndDate)).ToList()));
            var window = r.Blocked ? null : AccessWindowCalculator.Compute(spans, today);
            return new PlannedClient(r.ClientProfileId, r.AccessNo!.Value.ToString(), DisplayName(r.FirstName, r.LastName), r.Version, window);
        }).ToList();
    }

    public static string DisplayName(string firstName, string lastName)
    {
        var name = $"{firstName} {lastName}".Trim();
        if (Encoding.UTF8.GetByteCount(name) <= MaxNameBytes) return name;
        var sb = new StringBuilder();
        foreach (var rune in name.EnumerateRunes())
        {
            if (Encoding.UTF8.GetByteCount(sb.ToString() + rune) > MaxNameBytes) break;
            sb.Append(rune.ToString());
        }
        return sb.ToString().TrimEnd();
    }
}
