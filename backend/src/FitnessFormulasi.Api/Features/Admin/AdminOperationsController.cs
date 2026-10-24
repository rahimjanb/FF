using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

public class RecordVisitRequest
{
    [Required] public Guid ClientId { get; set; }
    /// <summary>Defaults to now. Must not be in the future.</summary>
    public DateTimeOffset? VisitedAt { get; set; }
}

public class TrainerRequestListQuery : PageQuery
{
    public TrainerRequestStatus? Status { get; set; }
    public Guid? TrainerId { get; set; }
}

public class SessionListQuery : PageQuery
{
    public Guid? TrainerId { get; set; }
    public Guid? ClientId { get; set; }
    public TrainingSessionStatus? Status { get; set; }
}

[ApiController]
[Route("api/admin")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminOperationsController(
    AppDbContext db, IClubClock clock, ICurrentUser currentUser, TrainerRequestService requests) : ControllerBase
{
    [HttpGet("trainer-requests")]
    public Task<PagedResult<TrainerRequestDto>> TrainerRequests([FromQuery] TrainerRequestListQuery query, CancellationToken ct)
    {
        var q = db.TrainerRequests.AsQueryable();
        if (query.Status is not null) q = q.Where(r => r.Status == query.Status);
        if (query.TrainerId is not null) q = q.Where(r => r.TrainerProfileId == query.TrainerId);
        return q.OrderByDescending(r => r.CreatedAt).ThenBy(r => r.Id).Select(Projections.Request).ToPagedAsync(query, ct);
    }

    [HttpPost("trainer-requests/{id:guid}/accept")]
    public Task<TrainerRequestDto> Accept(Guid id, RespondTrainerRequest req, CancellationToken ct) =>
        requests.RespondAsync(id, true, req.Comment, trainerId: null, ct);

    [HttpPost("trainer-requests/{id:guid}/reject")]
    public Task<TrainerRequestDto> Reject(Guid id, RespondTrainerRequest req, CancellationToken ct) =>
        requests.RespondAsync(id, false, req.Comment, trainerId: null, ct);

    [HttpGet("training-sessions")]
    public Task<PagedResult<TrainingSessionDto>> Sessions([FromQuery] SessionListQuery query, CancellationToken ct)
    {
        var q = db.TrainingSessions.AsQueryable();
        if (query.TrainerId is not null) q = q.Where(s => s.TrainerProfileId == query.TrainerId);
        if (query.ClientId is not null) q = q.Where(s => s.ClientProfileId == query.ClientId);
        if (query.Status is not null) q = q.Where(s => s.Status == query.Status);
        return q.OrderByDescending(s => s.StartsAt).ThenBy(s => s.Id).Select(Projections.Session).ToPagedAsync(query, ct);
    }

    [HttpGet("visits")]
    public Task<PagedResult<VisitDto>> Visits([FromQuery] PageQuery paging, [FromQuery] Guid? clientId, CancellationToken ct)
    {
        var q = db.Visits.AsQueryable();
        if (clientId is not null) q = q.Where(v => v.ClientProfileId == clientId);
        return q.OrderByDescending(v => v.VisitedAt).ThenBy(v => v.Id).Select(Projections.VisitExpr).ToPagedAsync(paging, ct);
    }

    /// <summary>
    /// Records a visit entered by staff and links it to the membership valid on that day.
    /// Turnstile integration (automatic visits and access decisions) is stage 2.
    /// </summary>
    [HttpPost("visits")]
    public async Task<ActionResult<VisitDto>> RecordVisit(RecordVisitRequest req, CancellationToken ct)
    {
        var visitedAt = (req.VisitedAt ?? clock.UtcNow).ToUniversalTime();
        if (visitedAt > clock.UtcNow.AddMinutes(5))
            throw ApiException.BadRequest("visit_in_future", "Visit time must not be in the future.");
        if (!await db.ClientProfiles.AnyAsync(c => c.Id == req.ClientId, ct)) throw ApiException.NotFound("Client");

        var day = clock.ToClubDate(visitedAt);
        var candidates = await db.Memberships
            .Where(m => m.ClientProfileId == req.ClientId && m.Status == MembershipStatus.Active && m.StartDate <= day && m.EndDate >= day)
            .Select(Projections.MembershipRowExpr).ToListAsync(ct);
        var membership = candidates.Select(r => r.ToDto(day)).FirstOrDefault(m => m.EffectiveStatus == MembershipEffectiveStatus.Active)
            ?? throw ApiException.Conflict("no_active_membership", "The client has no valid membership for this date.");

        var visit = new Visit { ClientProfileId = req.ClientId, MembershipId = membership.Id, VisitedAt = visitedAt, RecordedByUserId = currentUser.Id };
        db.Visits.Add(visit);
        await db.SaveChangesAsync(ct);
        var dto = await db.Visits.Where(v => v.Id == visit.Id).Select(Projections.VisitExpr).SingleAsync(ct);
        return StatusCode(StatusCodes.Status201Created, dto);
    }
}
