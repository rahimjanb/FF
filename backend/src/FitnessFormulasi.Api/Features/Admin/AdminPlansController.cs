using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

public class MembershipPlanRequest : IValidatableObject
{
    [Required, StringLength(128, MinimumLength = 1)] public string Name { get; set; } = "";
    [StringLength(1000)] public string? Description { get; set; }
    [Required] public MembershipPlanType Type { get; set; }
    [Range(1, 3660)] public int DurationDays { get; set; }
    [Range(1, 10000)] public int? VisitLimit { get; set; }
    [Range(typeof(decimal), "0", "1000000000")] public decimal Price { get; set; }
    public bool IsActive { get; set; } = true;

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (Type == MembershipPlanType.LimitedVisits && VisitLimit is null)
            yield return new ValidationResult("Visit limit is required for limited plans.", [nameof(VisitLimit)]);
        if (Type == MembershipPlanType.Unlimited && VisitLimit is not null)
            yield return new ValidationResult("Unlimited plans must not have a visit limit.", [nameof(VisitLimit)]);
    }
}

/// <summary>Membership plans are never deleted (memberships reference them); deactivate instead.</summary>
[ApiController]
[Route("api/admin/membership-plans")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminPlansController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<List<MembershipPlanDto>> List([FromQuery] bool includeInactive = true, CancellationToken ct = default) =>
        await db.MembershipPlans.Where(p => includeInactive || p.IsActive).OrderByDescending(p => p.IsActive).ThenBy(p => p.Name)
            .Select(Projections.Plan).ToListAsync(ct);

    [HttpGet("{id:guid}")]
    public async Task<MembershipPlanDto> Get(Guid id, CancellationToken ct) =>
        await db.MembershipPlans.Where(p => p.Id == id).Select(Projections.Plan).SingleOrDefaultAsync(ct) ?? throw ApiException.NotFound("Membership plan");

    [HttpPost]
    public async Task<ActionResult<MembershipPlanDto>> Create(MembershipPlanRequest req, CancellationToken ct)
    {
        var plan = new MembershipPlan { Name = req.Name.Trim() };
        Apply(plan, req);
        db.MembershipPlans.Add(plan);
        await SaveAsync(ct);
        return CreatedAtAction(nameof(Get), new { id = plan.Id }, await Get(plan.Id, ct));
    }

    /// <summary>Changes apply to future assignments; existing memberships keep their dates and visit limit.</summary>
    [HttpPut("{id:guid}")]
    public async Task<MembershipPlanDto> Update(Guid id, MembershipPlanRequest req, CancellationToken ct)
    {
        var plan = await db.MembershipPlans.SingleOrDefaultAsync(p => p.Id == id, ct) ?? throw ApiException.NotFound("Membership plan");
        Apply(plan, req);
        await SaveAsync(ct);
        return await Get(id, ct);
    }

    private static void Apply(MembershipPlan plan, MembershipPlanRequest req)
    {
        plan.Name = req.Name.Trim();
        plan.Description = AdminClientsController.Clean(req.Description);
        plan.Type = req.Type;
        plan.DurationDays = req.DurationDays;
        plan.VisitLimit = req.Type == MembershipPlanType.LimitedVisits ? req.VisitLimit : null;
        plan.Price = req.Price;
        plan.IsActive = req.IsActive;
    }

    private async Task SaveAsync(CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException e) when (e.InnerException is Npgsql.PostgresException { SqlState: Npgsql.PostgresErrorCodes.UniqueViolation })
        {
            throw ApiException.Conflict("plan_name_taken", "A plan with this name already exists.");
        }
    }
}
