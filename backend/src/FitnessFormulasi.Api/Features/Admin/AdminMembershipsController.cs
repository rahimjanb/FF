using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

public class MembershipListQuery : PageQuery
{
    public MembershipFilter? Status { get; set; }
    public Guid? ClientId { get; set; }
    public Guid? PlanId { get; set; }
}

[ApiController]
[Route("api/admin/memberships")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminMembershipsController(AppDbContext db, MembershipService memberships, IClubClock clock) : ControllerBase
{
    [HttpGet]
    public async Task<PagedResult<MembershipDto>> List([FromQuery] MembershipListQuery query, CancellationToken ct)
    {
        var q = memberships.Filter(db.Memberships, query.Status);
        if (query.ClientId is not null) q = q.Where(m => m.ClientProfileId == query.ClientId);
        if (query.PlanId is not null) q = q.Where(m => m.MembershipPlanId == query.PlanId);
        q = query.Status is MembershipFilter.ExpiringSoon or MembershipFilter.Active
            ? q.OrderBy(m => m.EndDate).ThenBy(m => m.Id)
            : q.OrderByDescending(m => m.StartDate).ThenByDescending(m => m.CreatedAt).ThenBy(m => m.Id);
        var page = await q.Select(Projections.MembershipRowExpr).ToPagedAsync(query, ct);
        var today = clock.Today;
        return new PagedResult<MembershipDto>(page.Items.Select(r => r.ToDto(today)).ToList(), page.Page, page.PageSize, page.TotalCount);
    }

    [HttpGet("{id:guid}")]
    public Task<MembershipDto> Get(Guid id, CancellationToken ct) => memberships.GetAsync(id, ct);

    /// <summary>Assigns a plan to a client. End date is computed from the plan duration in the club time zone.</summary>
    [HttpPost]
    public async Task<ActionResult<MembershipDto>> Assign(AssignMembershipRequest req, CancellationToken ct)
    {
        var dto = await memberships.AssignAsync(req, ct);
        return CreatedAtAction(nameof(Get), new { id = dto.Id }, dto);
    }

    /// <summary>Freeze, cancel, reactivate or correct dates.</summary>
    [HttpPut("{id:guid}")]
    public Task<MembershipDto> Update(Guid id, UpdateMembershipRequest req, CancellationToken ct) => memberships.UpdateAsync(id, req, ct);
}
