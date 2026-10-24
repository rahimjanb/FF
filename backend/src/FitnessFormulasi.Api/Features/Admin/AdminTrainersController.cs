using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

public class AdminCreateTrainerRequest
{
    [Required, PhoneE164] public string Phone { get; set; } = "";
    [Required, StrongPassword] public string Password { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string FirstName { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string LastName { get; set; } = "";
    [StringLength(128)] public string? Specialization { get; set; }
    [StringLength(2000)] public string? Bio { get; set; }
    [Range(0, 80)] public int? ExperienceYears { get; set; }
}

public class AdminUpdateTrainerRequest
{
    [Required, PhoneE164] public string Phone { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string FirstName { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string LastName { get; set; } = "";
    [StringLength(128)] public string? Specialization { get; set; }
    [StringLength(2000)] public string? Bio { get; set; }
    [Range(0, 80)] public int? ExperienceYears { get; set; }
    public bool IsAcceptingClients { get; set; }
    public bool IsActive { get; set; }
    public UserStatus Status { get; set; }
}

[ApiController]
[Route("api/admin/trainers")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminTrainersController(AppDbContext db, AuthService auth, TokenService tokens) : ControllerBase
{
    [HttpGet]
    public async Task<PagedResult<TrainerAdminDto>> List([FromQuery] PageQuery paging, [FromQuery] string? search, [FromQuery] bool? isActive, CancellationToken ct)
    {
        var q = db.TrainerProfiles.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var pattern = "%" + AdminClientsController.Escape(search.Trim()) + "%";
            q = q.Where(t => EF.Functions.ILike(t.User.FirstName + " " + t.User.LastName, pattern, "\\") || t.User.Phone.Contains(search.Trim()));
        }
        if (isActive is not null) q = q.Where(t => t.IsActive == isActive);
        return await q.OrderBy(t => t.User.FirstName).ThenBy(t => t.User.LastName).ThenBy(t => t.Id).Select(Projections.TrainerAdmin).ToPagedAsync(paging, ct);
    }

    [HttpGet("{id:guid}")]
    public async Task<TrainerAdminDto> Get(Guid id, CancellationToken ct) =>
        await db.TrainerProfiles.Where(t => t.Id == id).Select(Projections.TrainerAdmin).SingleOrDefaultAsync(ct)
        ?? throw ApiException.NotFound("Trainer");

    [HttpPost]
    public async Task<ActionResult<TrainerAdminDto>> Create(AdminCreateTrainerRequest req, CancellationToken ct)
    {
        var phone = PhoneNumber.Normalize(req.Phone)!;
        if (await db.Users.AnyAsync(u => u.Phone == phone, ct))
            throw ApiException.Conflict("phone_taken", "A user with this phone number already exists.");
        var user = await auth.CreateUserAsync(phone, req.Password, req.FirstName, req.LastName, RoleNames.Trainer, ct, assignedByStaff: true);
        var trainer = new TrainerProfile
        {
            UserId = user.Id,
            Specialization = AdminClientsController.Clean(req.Specialization),
            Bio = AdminClientsController.Clean(req.Bio),
            ExperienceYears = req.ExperienceYears,
        };
        db.TrainerProfiles.Add(trainer);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(Get), new { id = trainer.Id }, await Get(trainer.Id, ct));
    }

    [HttpPut("{id:guid}")]
    public async Task<TrainerAdminDto> Update(Guid id, AdminUpdateTrainerRequest req, CancellationToken ct)
    {
        var trainer = await db.TrainerProfiles.Include(t => t.User).SingleOrDefaultAsync(t => t.Id == id, ct) ?? throw ApiException.NotFound("Trainer");
        var phone = PhoneNumber.Normalize(req.Phone)!;
        if (phone != trainer.User.Phone)
        {
            if (await db.Users.AnyAsync(u => u.Phone == phone, ct))
                throw ApiException.Conflict("phone_taken", "A user with this phone number already exists.");
            trainer.User.Phone = phone;
            trainer.User.PhoneConfirmed = false;
        }
        trainer.User.FirstName = req.FirstName.Trim();
        trainer.User.LastName = req.LastName.Trim();
        trainer.Specialization = AdminClientsController.Clean(req.Specialization);
        trainer.Bio = AdminClientsController.Clean(req.Bio);
        trainer.ExperienceYears = req.ExperienceYears;
        trainer.IsAcceptingClients = req.IsAcceptingClients;
        trainer.IsActive = req.IsActive;
        var blocked = trainer.User.Status != UserStatus.Blocked && req.Status == UserStatus.Blocked;
        trainer.User.Status = req.Status;
        await db.SaveChangesAsync(ct);
        if (blocked) await tokens.RevokeAllAsync(trainer.UserId, ct);
        return await Get(id, ct);
    }

    [HttpPost("{id:guid}/reset-password")]
    public async Task<IActionResult> ResetPassword(Guid id, ResetPasswordRequest req, CancellationToken ct)
    {
        var trainer = await db.TrainerProfiles.Include(t => t.User).SingleOrDefaultAsync(t => t.Id == id, ct) ?? throw ApiException.NotFound("Trainer");
        await auth.ResetByStaffAsync(trainer.User, req.NewPassword, ct);
        return NoContent();
    }
}
