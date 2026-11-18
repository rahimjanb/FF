using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

public enum MembershipFilter { Active, Upcoming, Expired, Exhausted, Frozen, Cancelled, ExpiringSoon }

public class AssignMembershipRequest
{
    [Required] public Guid ClientId { get; set; }
    [Required] public Guid PlanId { get; set; }
    /// <summary>Club-local start date. Defaults to today.</summary>
    public DateOnly? StartDate { get; set; }
}

public class UpdateMembershipRequest
{
    [Required] public MembershipStatus Status { get; set; }
    [Required] public DateOnly StartDate { get; set; }
    [Required] public DateOnly EndDate { get; set; }
}

public class FreezeMembershipRequest
{
    /// <summary>First frozen day (club-local), today or later.</summary>
    [Required] public DateOnly StartDate { get; set; }
    /// <summary>Last frozen day, inclusive.</summary>
    [Required] public DateOnly EndDate { get; set; }
}

public sealed class MembershipService(AppDbContext db, IClubClock clock, ICurrentUser currentUser, NotificationService notifications)
{
    public const int ExpiringSoonDays = 7;
    /// <summary>Longest single freeze.</summary>
    public const int MaxFreezeDays = 30;
    /// <summary>Plans shorter than six months cannot be frozen.</summary>
    public const int MinFreezePlanDays = 180;
    public const int FreezesPerYear = 3;

    /// <summary>Freezes allowed for a membership of this plan length: none below six months, three per started year.</summary>
    public static int FreezesAllowed(int planDurationDays) =>
        planDurationDays < MinFreezePlanDays ? 0 : FreezesPerYear * ((planDurationDays + 364) / 365);

    public IQueryable<Membership> Filter(IQueryable<Membership> q, MembershipFilter? filter)
    {
        var today = clock.Today;
        var soon = today.AddDays(ExpiringSoonDays);
        return filter switch
        {
            MembershipFilter.Active => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate <= today && m.EndDate >= today
                                                    && !m.Freezes.Any(f => f.StartDate <= today && f.EndDate >= today)
                                                    && (m.VisitLimit == null || m.Visits.Count() < m.VisitLimit)),
            MembershipFilter.ExpiringSoon => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate <= today
                                                    && m.EndDate >= today && m.EndDate <= soon),
            MembershipFilter.Upcoming => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate > today),
            MembershipFilter.Expired => q.Where(m => m.Status != MembershipStatus.Cancelled && m.EndDate < today),
            MembershipFilter.Exhausted => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate <= today && m.EndDate >= today
                                                    && !m.Freezes.Any(f => f.StartDate <= today && f.EndDate >= today)
                                                    && m.VisitLimit != null && m.Visits.Count() >= m.VisitLimit),
            MembershipFilter.Frozen => q.Where(m => m.EndDate >= today && (m.Status == MembershipStatus.Frozen
                                                    || (m.Status == MembershipStatus.Active && m.Freezes.Any(f => f.StartDate <= today && f.EndDate >= today)))),
            MembershipFilter.Cancelled => q.Where(m => m.Status == MembershipStatus.Cancelled),
            _ => q,
        };
    }

    /// <summary>The membership valid today, or the one in effect today (frozen/exhausted) if none is usable.</summary>
    public async Task<MembershipDto?> CurrentForClientAsync(Guid clientId, CancellationToken ct)
    {
        var today = clock.Today;
        var rows = await db.Memberships.Where(m => m.ClientProfileId == clientId && m.Status != MembershipStatus.Cancelled
                                                   && m.StartDate <= today && m.EndDate >= today)
            .OrderByDescending(m => m.EndDate).Select(Projections.MembershipRowExpr).ToListAsync(ct);
        var dtos = rows.Select(r => r.ToDto(today)).ToList();
        return dtos.FirstOrDefault(d => d.EffectiveStatus == MembershipEffectiveStatus.Active) ?? dtos.FirstOrDefault();
    }

    public async Task<MembershipDto?> NextForClientAsync(Guid clientId, CancellationToken ct)
    {
        var today = clock.Today;
        var row = await db.Memberships.Where(m => m.ClientProfileId == clientId && m.Status == MembershipStatus.Active && m.StartDate > today)
            .OrderBy(m => m.StartDate).Select(Projections.MembershipRowExpr).FirstOrDefaultAsync(ct);
        return row?.ToDto(today);
    }

    public async Task<List<MembershipDto>> ForClientAsync(Guid clientId, CancellationToken ct)
    {
        var today = clock.Today;
        var rows = await db.Memberships.Where(m => m.ClientProfileId == clientId)
            .OrderByDescending(m => m.StartDate).Select(Projections.MembershipRowExpr).ToListAsync(ct);
        return rows.Select(r => r.ToDto(today)).ToList();
    }

    public async Task<MembershipDto> GetAsync(Guid id, CancellationToken ct)
    {
        var row = await db.Memberships.Where(m => m.Id == id).Select(Projections.MembershipRowExpr).SingleOrDefaultAsync(ct)
                  ?? throw ApiException.NotFound("Membership");
        return row.ToDto(clock.Today);
    }

    public async Task<MembershipDto> AssignAsync(AssignMembershipRequest req, CancellationToken ct)
    {
        var today = clock.Today;
        var start = req.StartDate ?? today;
        if (Math.Abs(start.DayNumber - today.DayNumber) > 366)
            throw ApiException.BadRequest("invalid_start_date", "Start date must be within one year from today.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var client = await LockClientAsync(req.ClientId, ct);
        var membership = await AddMembershipAsync(client, req.PlanId, start, ct);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(membership.Id, ct);
    }

    /// <summary>
    /// Adds a membership for a client locked by the caller's transaction and notifies the client; the caller saves.
    /// </summary>
    public async Task<Membership> AddMembershipAsync(ClientProfile client, Guid planId, DateOnly start, CancellationToken ct)
    {
        if (await db.Users.AnyAsync(u => u.Id == client.UserId && u.Status == UserStatus.Deleted, ct))
            throw ApiException.Conflict("client_deleted", "The client's account has been deleted.");
        var plan = await db.MembershipPlans.SingleOrDefaultAsync(p => p.Id == planId, ct) ?? throw ApiException.NotFound("Membership plan");
        if (!plan.IsActive) throw ApiException.Conflict("plan_inactive", "The membership plan is not available.");
        var end = start.AddDays(plan.DurationDays - 1);
        await EnsureNoOverlapAsync(client.Id, start, end, null, ct);

        var membership = new Membership
        {
            ClientProfileId = client.Id,
            MembershipPlanId = plan.Id,
            StartDate = start,
            EndDate = end,
            VisitLimit = plan.VisitLimit,
            CreatedByUserId = currentUser.Id,
        };
        db.Memberships.Add(membership);
        notifications.Add(client.UserId, NotificationType.MembershipAssigned, membership.Id, plan.Name);
        return membership;
    }

    /// <summary>
    /// Freezes the membership for the given days and moves its end date (and any later memberships of the client)
    /// forward by the same number of days. Visits are not accepted while frozen. The same rules apply to the client
    /// (<paramref name="clientId"/> set, own memberships only) and to staff: plans of six months or longer,
    /// <see cref="FreezesAllowed"/> times, at most <see cref="MaxFreezeDays"/> days each.
    /// </summary>
    public async Task<MembershipDto> FreezeAsync(Guid id, FreezeMembershipRequest req, CancellationToken ct, Guid? clientId = null)
    {
        var today = clock.Today;
        if (req.EndDate < req.StartDate)
            throw ApiException.BadRequest("invalid_dates", "End date must not be before start date.");
        if (req.StartDate < today)
            throw ApiException.BadRequest("freeze_in_past", "A freeze must not start in the past.");
        var days = req.EndDate.DayNumber - req.StartDate.DayNumber + 1;
        if (days > MaxFreezeDays)
            throw ApiException.BadRequest("freeze_too_long", $"A freeze may last at most {MaxFreezeDays} days.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var membership = await db.Memberships.Include(m => m.Plan)
                             .SingleOrDefaultAsync(m => m.Id == id && (clientId == null || m.ClientProfileId == clientId), ct)
                         ?? throw ApiException.NotFound("Membership");
        var client = await LockClientAsync(membership.ClientProfileId, ct);
        if (membership.Status != MembershipStatus.Active)
            throw ApiException.Conflict("membership_not_active", "Only an active membership can be frozen.");
        if (membership.EndDate < today)
            throw ApiException.Conflict("membership_expired", "The membership has already ended.");
        var allowed = FreezesAllowed(membership.Plan.DurationDays);
        if (allowed == 0)
            throw ApiException.Conflict("freeze_not_available", "Freezing is available for memberships of six months or longer.");
        if (req.StartDate > membership.EndDate || req.StartDate < membership.StartDate)
            throw ApiException.BadRequest("freeze_outside_membership", "The freeze must start within the membership period.");
        if (await db.MembershipFreezes.AnyAsync(f => f.MembershipId == id && f.EndDate >= today, ct))
            throw ApiException.Conflict("freeze_exists", "The membership already has a current or planned freeze.");
        if (await db.MembershipFreezes.CountAsync(f => f.MembershipId == id, ct) >= allowed)
            throw ApiException.Conflict("freeze_limit_reached", $"All {allowed} freezes of this membership have been used.");

        var oldEnd = membership.EndDate;
        membership.EndDate = oldEnd.AddDays(days);
        await ShiftLaterMembershipsAsync(membership, oldEnd, days, ct);
        db.MembershipFreezes.Add(new MembershipFreeze
        {
            MembershipId = id, StartDate = req.StartDate, EndDate = req.EndDate, CreatedByUserId = currentUser.Id,
        });
        // The client is notified when staff froze the membership; one who froze it in the app already knows.
        if (currentUser.Id != client.UserId)
            notifications.Add(client.UserId, NotificationType.MembershipFrozen, id, $"{req.StartDate:yyyy-MM-dd}/{req.EndDate:yyyy-MM-dd}");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(id, ct);
    }

    /// <summary>
    /// Ends the current or planned freeze today; the unused days are taken back from the end date. A planned freeze
    /// that has not started is deleted and does not count towards the limit. <paramref name="clientId"/>: own memberships only.
    /// </summary>
    public async Task<MembershipDto> UnfreezeAsync(Guid id, CancellationToken ct, Guid? clientId = null)
    {
        var today = clock.Today;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var membership = await db.Memberships.SingleOrDefaultAsync(m => m.Id == id && (clientId == null || m.ClientProfileId == clientId), ct)
                         ?? throw ApiException.NotFound("Membership");
        var client = await LockClientAsync(membership.ClientProfileId, ct);
        var freeze = await db.MembershipFreezes.Where(f => f.MembershipId == id && f.EndDate >= today)
                         .OrderByDescending(f => f.StartDate).FirstOrDefaultAsync(ct)
                     ?? throw ApiException.Conflict("not_frozen", "The membership has no current or planned freeze.");

        var from = freeze.StartDate > today ? freeze.StartDate : today;
        var unused = freeze.EndDate.DayNumber - from.DayNumber + 1;
        if (freeze.StartDate >= today) db.MembershipFreezes.Remove(freeze);
        else freeze.EndDate = today.AddDays(-1);

        var oldEnd = membership.EndDate;
        membership.EndDate = oldEnd.AddDays(-unused);
        await ShiftLaterMembershipsAsync(membership, oldEnd, -unused, ct);
        if (currentUser.Id != client.UserId)
            notifications.Add(client.UserId, NotificationType.MembershipUnfrozen, id, $"{membership.EndDate:yyyy-MM-dd}");
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(id, ct);
    }

    /// <summary>Memberships the client already has after this one move together with its end date.</summary>
    private async Task ShiftLaterMembershipsAsync(Membership membership, DateOnly oldEnd, int days, CancellationToken ct)
    {
        var later = await db.Memberships.Where(m => m.ClientProfileId == membership.ClientProfileId && m.Id != membership.Id
                                                    && m.Status != MembershipStatus.Cancelled && m.StartDate > oldEnd)
            .ToListAsync(ct);
        foreach (var m in later)
        {
            m.StartDate = m.StartDate.AddDays(days);
            m.EndDate = m.EndDate.AddDays(days);
        }
    }

    /// <summary>
    /// Ends the client's membership that covers <paramref name="day"/> the day before it (or cancels it if it has not
    /// started by then), so a new plan can start that day. Freezes past the new end are dropped.
    /// </summary>
    public async Task CloseCoveringAsync(Guid clientId, DateOnly day, CancellationToken ct)
    {
        var current = await db.Memberships.Include(m => m.Freezes)
            .Where(m => m.ClientProfileId == clientId && m.Status != MembershipStatus.Cancelled && m.StartDate <= day && m.EndDate >= day)
            .ToListAsync(ct);
        foreach (var m in current)
        {
            if (m.StartDate >= day)
            {
                m.Status = MembershipStatus.Cancelled;
                continue;
            }
            m.EndDate = day.AddDays(-1);
            foreach (var f in m.Freezes.Where(f => f.EndDate > m.EndDate).ToList())
            {
                if (f.StartDate > m.EndDate) db.MembershipFreezes.Remove(f);
                else f.EndDate = m.EndDate;
            }
        }
    }

    public async Task<MembershipDto> UpdateAsync(Guid id, UpdateMembershipRequest req, CancellationToken ct)
    {
        if (req.EndDate < req.StartDate)
            throw ApiException.BadRequest("invalid_dates", "End date must not be before start date.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var membership = await db.Memberships.SingleOrDefaultAsync(m => m.Id == id, ct) ?? throw ApiException.NotFound("Membership");
        await LockClientAsync(membership.ClientProfileId, ct);
        if (req.Status != MembershipStatus.Cancelled)
            await EnsureNoOverlapAsync(membership.ClientProfileId, req.StartDate, req.EndDate, id, ct);

        membership.Status = req.Status;
        membership.StartDate = req.StartDate;
        membership.EndDate = req.EndDate;
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(id, ct);
    }

    /// <summary>Row lock on the client serializes membership changes for that client (prevents overlapping inserts).</summary>
    public async Task<ClientProfile> LockClientAsync(Guid clientId, CancellationToken ct) =>
        await db.ClientProfiles.FromSql($"SELECT * FROM \"ClientProfiles\" WHERE \"Id\" = {clientId} FOR UPDATE").SingleOrDefaultAsync(ct)
        ?? throw ApiException.NotFound("Client");

    private async Task EnsureNoOverlapAsync(Guid clientId, DateOnly start, DateOnly end, Guid? exceptId, CancellationToken ct)
    {
        var overlaps = await db.Memberships.AnyAsync(m => m.ClientProfileId == clientId && m.Id != exceptId
                                                          && m.Status != MembershipStatus.Cancelled
                                                          && m.StartDate <= end && m.EndDate >= start, ct);
        if (overlaps)
            throw ApiException.Conflict("membership_overlap", "The client already has a membership for these dates.");
    }
}
