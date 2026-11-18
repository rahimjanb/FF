using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

public class MembershipRequestListQuery : PageQuery
{
    public MembershipRequestStatus? Status { get; set; }
}

[ApiController]
[Route("api/admin/membership-requests")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminMembershipRequestsController(
    AppDbContext db, IClubClock clock, MembershipService memberships, MembershipRequestService requests) : ControllerBase
{
    /// <summary>Requests from the app; pending ones first come oldest first, so the queue is served in order.</summary>
    [HttpGet]
    public async Task<PagedResult<MembershipRequestAdminDto>> List([FromQuery] MembershipRequestListQuery query, CancellationToken ct)
    {
        var q = db.MembershipRequests.AsQueryable();
        if (query.Status is not null) q = q.Where(r => r.Status == query.Status);
        q = query.Status == MembershipRequestStatus.Pending
            ? q.OrderBy(r => r.CreatedAt).ThenBy(r => r.Id)
            : q.OrderByDescending(r => r.CreatedAt).ThenBy(r => r.Id);
        var page = await q.Select(Projections.MembershipRequestExpr).ToPagedAsync(query, ct);

        var today = clock.Today;
        var items = new List<MembershipRequestAdminDto>(page.Items.Count);
        foreach (var r in page.Items)
        {
            if (r.Status != MembershipRequestStatus.Pending)
            {
                items.Add(new MembershipRequestAdminDto(r, null, null));
                continue;
            }
            items.Add(new MembershipRequestAdminDto(r, await memberships.CurrentForClientAsync(r.Client.Id, ct),
                await requests.DefaultStartAsync(r.Client.Id, today, ct)));
        }
        return new PagedResult<MembershipRequestAdminDto>(items, page.Page, page.PageSize, page.TotalCount);
    }

    /// <summary>Payment taken at the desk: assigns the requested plan and notifies the client.</summary>
    [HttpPost("{id:guid}/complete")]
    public Task<MembershipRequestDto> Complete(Guid id, CompleteMembershipRequest req, CancellationToken ct) =>
        requests.CompleteAsync(id, req, ct);

    [HttpPost("{id:guid}/reject")]
    public Task<MembershipRequestDto> Reject(Guid id, RejectMembershipRequest req, CancellationToken ct) =>
        requests.RejectAsync(id, req, ct);
}
