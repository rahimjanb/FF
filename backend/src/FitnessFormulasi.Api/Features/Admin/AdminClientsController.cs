using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

public class AdminCreateClientRequest
{
    [Required, PhoneE164] public string Phone { get; set; } = "";
    [Required, StrongPassword] public string Password { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string FirstName { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string LastName { get; set; } = "";
    [EmailAddress, StringLength(256)] public string? Email { get; set; }
    [PastDate] public DateOnly? BirthDate { get; set; }
    public Gender? Gender { get; set; }
    [StringLength(2000)] public string? Notes { get; set; }
}

public class AdminUpdateClientRequest
{
    [Required, PhoneE164] public string Phone { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string FirstName { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string LastName { get; set; } = "";
    [EmailAddress, StringLength(256)] public string? Email { get; set; }
    [PastDate] public DateOnly? BirthDate { get; set; }
    public Gender? Gender { get; set; }
    [StringLength(2000)] public string? Notes { get; set; }
    public UserStatus Status { get; set; }
    public Guid? AssignedTrainerId { get; set; }
}

public class ResetPasswordRequest
{
    [Required, StrongPassword] public string NewPassword { get; set; } = "";
}

public class ClientListQuery : PageQuery
{
    [StringLength(100)] public string? Search { get; set; }
    public UserStatus? Status { get; set; }
    public Guid? TrainerId { get; set; }
    public bool? HasActiveMembership { get; set; }
}

[ApiController]
[Route("api/admin/clients")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminClientsController(
    AppDbContext db, AuthService auth, TokenService tokens, MembershipService memberships) : ControllerBase
{
    [HttpGet]
    public async Task<PagedResult<ClientAdminDto>> List([FromQuery] ClientListQuery query, CancellationToken ct)
    {
        var q = db.ClientProfiles.AsQueryable();
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var term = query.Search.Trim();
            var digits = new string(term.Where(char.IsDigit).ToArray());
            var pattern = "%" + Escape(term) + "%";
            q = q.Where(c => EF.Functions.ILike(c.User.FirstName, pattern, "\\") || EF.Functions.ILike(c.User.LastName, pattern, "\\")
                             || EF.Functions.ILike(c.User.FirstName + " " + c.User.LastName, pattern, "\\")
                             || (digits.Length >= 3 && c.User.Phone.Contains(digits)));
        }
        if (query.Status is not null) q = q.Where(c => c.User.Status == query.Status);
        if (query.TrainerId is not null) q = q.Where(c => c.AssignedTrainerId == query.TrainerId);
        if (query.HasActiveMembership is not null)
        {
            var activeIds = memberships.Filter(db.Memberships, MembershipFilter.Active).Select(m => m.ClientProfileId);
            q = query.HasActiveMembership.Value ? q.Where(c => activeIds.Contains(c.Id)) : q.Where(c => !activeIds.Contains(c.Id));
        }

        var page = await q.OrderByDescending(c => c.CreatedAt).ThenBy(c => c.Id).Select(c => c.Id).ToPagedAsync(query, ct);
        var items = new List<ClientAdminDto>();
        foreach (var id in page.Items) items.Add(await LoadAsync(id, ct));
        return new PagedResult<ClientAdminDto>(items, page.Page, page.PageSize, page.TotalCount);
    }

    [HttpGet("{id:guid}")]
    public Task<ClientAdminDto> Get(Guid id, CancellationToken ct) => LoadAsync(id, ct);

    [HttpGet("{id:guid}/memberships")]
    public async Task<List<MembershipDto>> Memberships(Guid id, CancellationToken ct)
    {
        await EnsureExistsAsync(id, ct);
        return await memberships.ForClientAsync(id, ct);
    }

    [HttpPost]
    public async Task<ActionResult<ClientAdminDto>> Create(AdminCreateClientRequest req, CancellationToken ct)
    {
        var phone = PhoneNumber.Normalize(req.Phone)!;
        if (await db.Users.AnyAsync(u => u.Phone == phone, ct))
            throw ApiException.Conflict("phone_taken", "A user with this phone number already exists.");
        var user = await auth.CreateUserAsync(phone, req.Password, req.FirstName, req.LastName, RoleNames.Client, ct, assignedByStaff: true);
        user.Email = Clean(req.Email);
        var client = new ClientProfile { UserId = user.Id, BirthDate = req.BirthDate, Gender = req.Gender, Notes = Clean(req.Notes) };
        db.ClientProfiles.Add(client);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(Get), new { id = client.Id }, await LoadAsync(client.Id, ct));
    }

    [HttpPut("{id:guid}")]
    public async Task<ClientAdminDto> Update(Guid id, AdminUpdateClientRequest req, CancellationToken ct)
    {
        var client = await db.ClientProfiles.Include(c => c.User).SingleOrDefaultAsync(c => c.Id == id, ct) ?? throw ApiException.NotFound("Client");
        var phone = PhoneNumber.Normalize(req.Phone)!;
        if (phone != client.User.Phone)
        {
            if (await db.Users.AnyAsync(u => u.Phone == phone, ct))
                throw ApiException.Conflict("phone_taken", "A user with this phone number already exists.");
            client.User.Phone = phone;
            client.User.PhoneConfirmed = false;
        }
        if (req.AssignedTrainerId is not null && req.AssignedTrainerId != client.AssignedTrainerId
            && !await db.TrainerProfiles.AnyAsync(t => t.Id == req.AssignedTrainerId && t.IsActive, ct))
            throw ApiException.BadRequest("trainer_not_found", "Trainer not found or inactive.");

        client.User.FirstName = req.FirstName.Trim();
        client.User.LastName = req.LastName.Trim();
        client.User.Email = Clean(req.Email);
        client.BirthDate = req.BirthDate;
        client.Gender = req.Gender;
        client.Notes = Clean(req.Notes);
        client.AssignedTrainerId = req.AssignedTrainerId;
        var blocked = client.User.Status != UserStatus.Blocked && req.Status == UserStatus.Blocked;
        client.User.Status = req.Status;
        await db.SaveChangesAsync(ct);
        if (blocked) await tokens.RevokeAllAsync(client.UserId, ct);
        return await LoadAsync(id, ct);
    }

    /// <summary>
    /// Sets a temporary password (stage 1 has no SMS reset). The client must replace it at next sign-in;
    /// all sessions of the user are revoked.
    /// </summary>
    [HttpPost("{id:guid}/reset-password")]
    public async Task<IActionResult> ResetPassword(Guid id, ResetPasswordRequest req, CancellationToken ct)
    {
        var client = await db.ClientProfiles.Include(c => c.User).SingleOrDefaultAsync(c => c.Id == id, ct) ?? throw ApiException.NotFound("Client");
        await auth.ResetByStaffAsync(client.User, req.NewPassword, ct);
        return NoContent();
    }

    private async Task EnsureExistsAsync(Guid id, CancellationToken ct)
    {
        if (!await db.ClientProfiles.AnyAsync(c => c.Id == id, ct)) throw ApiException.NotFound("Client");
    }

    private async Task<ClientAdminDto> LoadAsync(Guid id, CancellationToken ct)
    {
        var c = await db.ClientProfiles.Where(x => x.Id == id).Select(x => new
        {
            x.Id, x.UserId, x.User.Phone, x.User.PhoneConfirmed, x.User.FirstName, x.User.LastName, x.User.Email,
            x.BirthDate, x.Gender, x.Notes, x.User.Status, x.CreatedAt,
            Trainer = x.AssignedTrainer == null ? null : new PersonRef(x.AssignedTrainer.Id, x.AssignedTrainer.User.FirstName, x.AssignedTrainer.User.LastName),
        }).SingleOrDefaultAsync(ct) ?? throw ApiException.NotFound("Client");
        return new ClientAdminDto(c.Id, c.UserId, c.Phone, c.PhoneConfirmed, c.FirstName, c.LastName, c.Email, c.BirthDate, c.Gender,
            c.Notes, c.Status, c.Trainer, await memberships.CurrentForClientAsync(c.Id, ct), c.CreatedAt);
    }

    internal static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    internal static string Escape(string s) => s.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_");
}
