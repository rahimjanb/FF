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

    public const int MaxPhotoBytes = 2 * 1024 * 1024;

    /// <summary>Sets the trainer photo (JPEG, PNG or WebP up to 2 MB). The format is checked by content, not by name.</summary>
    [HttpPut("{id:guid}/photo")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxPhotoBytes + 64 * 1024)]
    public async Task<TrainerAdminDto> SetPhoto(Guid id, IFormFile file, CancellationToken ct)
    {
        var trainer = await db.TrainerProfiles.SingleOrDefaultAsync(t => t.Id == id, ct) ?? throw ApiException.NotFound("Trainer");
        if (file.Length == 0 || file.Length > MaxPhotoBytes)
            throw ApiException.BadRequest("photo_too_large", "The photo must be up to 2 MB.");
        using var buffer = new MemoryStream();
        await file.CopyToAsync(buffer, ct);
        var data = buffer.ToArray();
        var type = ImageType(data) ?? throw ApiException.BadRequest("photo_invalid_format", "Only JPEG, PNG or WebP images are accepted.");

        var photo = await db.TrainerPhotos.SingleOrDefaultAsync(p => p.TrainerProfileId == id, ct);
        if (photo is null) db.TrainerPhotos.Add(new TrainerPhoto { TrainerProfileId = id, Data = data, ContentType = type });
        else (photo.Data, photo.ContentType) = (data, type);
        trainer.PhotoVersion++;
        await db.SaveChangesAsync(ct);
        return await Get(id, ct);
    }

    [HttpDelete("{id:guid}/photo")]
    public async Task<TrainerAdminDto> DeletePhoto(Guid id, CancellationToken ct)
    {
        var trainer = await db.TrainerProfiles.SingleOrDefaultAsync(t => t.Id == id, ct) ?? throw ApiException.NotFound("Trainer");
        await db.TrainerPhotos.Where(p => p.TrainerProfileId == id).ExecuteDeleteAsync(ct);
        trainer.PhotoVersion = 0;
        await db.SaveChangesAsync(ct);
        return await Get(id, ct);
    }

    private static string? ImageType(byte[] d) => d switch
    {
        [0xFF, 0xD8, 0xFF, ..] => "image/jpeg",
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ..] => "image/png",
        [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ..] => "image/webp",
        _ => null,
    };

    [HttpPost("{id:guid}/reset-password")]
    public async Task<IActionResult> ResetPassword(Guid id, ResetPasswordRequest req, CancellationToken ct)
    {
        var trainer = await db.TrainerProfiles.Include(t => t.User).SingleOrDefaultAsync(t => t.Id == id, ct) ?? throw ApiException.NotFound("Trainer");
        await auth.ResetByStaffAsync(trainer.User, req.NewPassword, ct);
        return NoContent();
    }
}
