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

public sealed class MembershipService(AppDbContext db, IClubClock clock, ICurrentUser currentUser, NotificationService notifications)
{
    public const int ExpiringSoonDays = 7;

    public IQueryable<Membership> Filter(IQueryable<Membership> q, MembershipFilter? filter)
    {
        var today = clock.Today;
        var soon = today.AddDays(ExpiringSoonDays);
        return filter switch
        {
            MembershipFilter.Active => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate <= today && m.EndDate >= today
                                                    && (m.VisitLimit == null || m.Visits.Count() < m.VisitLimit)),
            MembershipFilter.ExpiringSoon => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate <= today
                                                    && m.EndDate >= today && m.EndDate <= soon),
            MembershipFilter.Upcoming => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate > today),
            MembershipFilter.Expired => q.Where(m => m.Status != MembershipStatus.Cancelled && m.EndDate < today),
            MembershipFilter.Exhausted => q.Where(m => m.Status == MembershipStatus.Active && m.StartDate <= today && m.EndDate >= today
                                                    && m.VisitLimit != null && m.Visits.Count() >= m.VisitLimit),
            MembershipFilter.Frozen => q.Where(m => m.Status == MembershipStatus.Frozen && m.EndDate >= today),
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

        var plan = await db.MembershipPlans.SingleOrDefaultAsync(p => p.Id == req.PlanId, ct) ?? throw ApiException.NotFound("Membership plan");
        if (!plan.IsActive) throw ApiException.Conflict("plan_inactive", "The membership plan is not available.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var client = await LockClientAsync(req.ClientId, ct);
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
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(membership.Id, ct);
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
    private async Task<ClientProfile> LockClientAsync(Guid clientId, CancellationToken ct) =>
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
