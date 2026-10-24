using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

public record AdminDashboardDto(
    int TotalClients, int NewClientsThisMonth, int ActiveMemberships, int ExpiringSoon, int ActiveTrainers,
    int PendingTrainerRequests, int VisitsToday, int SessionsToday, DateOnly Today);

public record CountByKey(string Key, int Count);
public record DailyCount(DateOnly Date, int Count);
public record TrainerLoad(Guid TrainerId, string Name, int Clients, int SessionsCompleted, int RequestsReceived);

public record ReportDto(
    DateOnly From, DateOnly To, int NewClients, int MembershipsAssigned, IReadOnlyList<CountByKey> MembershipsByPlan,
    int Visits, IReadOnlyList<DailyCount> VisitsByDay, IReadOnlyList<CountByKey> TrainerRequestsByStatus,
    IReadOnlyList<CountByKey> SessionsByStatus, IReadOnlyList<TrainerLoad> Trainers);

/// <summary>All figures are computed from recorded data only; nothing is estimated or synthesized.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminReportsController(AppDbContext db, IClubClock clock, MembershipService memberships) : ControllerBase
{
    [HttpGet("dashboard")]
    public async Task<AdminDashboardDto> Dashboard(CancellationToken ct)
    {
        var today = clock.Today;
        var dayStart = clock.StartOfDayUtc(today);
        var dayEnd = clock.StartOfDayUtc(today.AddDays(1));
        var monthStart = clock.StartOfDayUtc(new DateOnly(today.Year, today.Month, 1));
        return new AdminDashboardDto(
            await db.ClientProfiles.CountAsync(ct),
            await db.ClientProfiles.CountAsync(c => c.CreatedAt >= monthStart, ct),
            await memberships.Filter(db.Memberships, MembershipFilter.Active).CountAsync(ct),
            await memberships.Filter(db.Memberships, MembershipFilter.ExpiringSoon).CountAsync(ct),
            await db.TrainerProfiles.CountAsync(t => t.IsActive && t.User.Status == UserStatus.Active, ct),
            await db.TrainerRequests.CountAsync(r => r.Status == TrainerRequestStatus.Pending, ct),
            await db.Visits.CountAsync(v => v.VisitedAt >= dayStart && v.VisitedAt < dayEnd, ct),
            await db.TrainingSessions.CountAsync(s => s.StartsAt >= dayStart && s.StartsAt < dayEnd && s.Status != TrainingSessionStatus.Cancelled, ct),
            today);
    }

    /// <summary>Summary for a club-local date range (inclusive), at most 366 days. Defaults to the current month.</summary>
    [HttpGet("reports/summary")]
    public async Task<ReportDto> Summary([FromQuery] DateOnly? from, [FromQuery] DateOnly? to, CancellationToken ct)
    {
        var today = clock.Today;
        var f = from ?? new DateOnly(today.Year, today.Month, 1);
        var t = to ?? today;
        if (t < f || t.DayNumber - f.DayNumber > 366)
            throw ApiException.BadRequest("invalid_range", "Date range must be positive and at most 366 days.");
        var start = clock.StartOfDayUtc(f);
        var end = clock.StartOfDayUtc(t.AddDays(1));

        var assigned = db.Memberships.Where(m => m.CreatedAt >= start && m.CreatedAt < end);
        var byPlan = await assigned.GroupBy(m => m.Plan.Name).Select(g => new CountByKey(g.Key, g.Count())).ToListAsync(ct);

        var visitTimes = await db.Visits.Where(v => v.VisitedAt >= start && v.VisitedAt < end).Select(v => v.VisitedAt).ToListAsync(ct);
        var visitsByDay = visitTimes.GroupBy(clock.ToClubDate).Select(g => new DailyCount(g.Key, g.Count())).OrderBy(d => d.Date).ToList();

        var requestsByStatus = await db.TrainerRequests.Where(r => r.CreatedAt >= start && r.CreatedAt < end)
            .GroupBy(r => r.Status).Select(g => new { g.Key, Count = g.Count() }).ToListAsync(ct);
        var sessionsByStatus = await db.TrainingSessions.Where(s => s.StartsAt >= start && s.StartsAt < end)
            .GroupBy(s => s.Status).Select(g => new { g.Key, Count = g.Count() }).ToListAsync(ct);

        var trainers = await db.TrainerProfiles.Where(tp => tp.IsActive).OrderByDescending(tp => tp.Clients.Count()).Select(tp => new TrainerLoad(
            tp.Id, tp.User.FirstName + " " + tp.User.LastName, tp.Clients.Count(),
            db.TrainingSessions.Count(s => s.TrainerProfileId == tp.Id && s.Status == TrainingSessionStatus.Completed && s.StartsAt >= start && s.StartsAt < end),
            db.TrainerRequests.Count(r => r.TrainerProfileId == tp.Id && r.CreatedAt >= start && r.CreatedAt < end)))
            .ToListAsync(ct);

        return new ReportDto(f, t,
            await db.ClientProfiles.CountAsync(c => c.CreatedAt >= start && c.CreatedAt < end, ct),
            await assigned.CountAsync(ct), byPlan, visitTimes.Count, visitsByDay,
            requestsByStatus.Select(x => new CountByKey(x.Key.ToString(), x.Count)).ToList(),
            sessionsByStatus.Select(x => new CountByKey(x.Key.ToString(), x.Count)).ToList(),
            trainers);
    }
}
