using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Access;

/// <summary>Upload form: the JPEG photo and the consent checkbox.</summary>
public class FaceUploadForm
{
    public IFormFile? File { get; set; }
    /// <summary>Consent to processing the face photo for entry through the turnstile. Must be true.</summary>
    public bool Consent { get; set; }
}

/// <summary>The client's own face photo for entry through the turnstile.</summary>
[ApiController]
[Route("api/me/face")]
[Authorize(Roles = RoleNames.Client)]
[Produces("application/json")]
public class ClientFaceController(Profiles profiles, FaceService faces) : ControllerBase
{
    [HttpGet]
    public async Task<FaceAccessDto> Get(CancellationToken ct) => await faces.StatusAsync(await profiles.ClientIdAsync(ct), ct);

    /// <summary>The photo itself, to show it to its owner. Never cached by intermediaries.</summary>
    [HttpGet("photo")]
    [Produces("image/jpeg")]
    public async Task<IActionResult> Photo(CancellationToken ct)
    {
        var data = await faces.PhotoAsync(await profiles.ClientIdAsync(ct), ct) ?? throw ApiException.NotFound("Face photo");
        Response.Headers.CacheControl = "private, no-store";
        return File(data, "image/jpeg");
    }

    /// <summary>Sets or replaces the photo: JPEG up to 200 KB, at least 240 px on each side, with consent.</summary>
    [HttpPut]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(FaceService.MaxFaceBytes + 64 * 1024)]
    public async Task<FaceAccessDto> Upload([FromForm] FaceUploadForm form, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        await faces.UploadAsync(clientId, form.File, form.Consent, ct);
        return await faces.StatusAsync(clientId, ct);
    }

    /// <summary>Deletes the photo; the client is removed from the terminals within a minute.</summary>
    [HttpDelete]
    public async Task<FaceAccessDto> Delete(CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        await faces.DeleteAsync(clientId, ct);
        return await faces.StatusAsync(clientId, ct);
    }
}

/// <summary>A client's face photo managed at the desk, e.g. taken with the reception camera.</summary>
[ApiController]
[Route("api/admin/clients/{clientId:guid}/face")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminClientFaceController(AppDbContext db, FaceService faces) : ControllerBase
{
    [HttpGet]
    public async Task<FaceAccessAdminDto> Get(Guid clientId, CancellationToken ct)
    {
        await EnsureClientAsync(clientId, ct);
        return await faces.AdminStatusAsync(clientId, ct);
    }

    [HttpGet("photo")]
    [Produces("image/jpeg")]
    public async Task<IActionResult> Photo(Guid clientId, CancellationToken ct)
    {
        var data = await faces.PhotoAsync(clientId, ct) ?? throw ApiException.NotFound("Face photo");
        Response.Headers.CacheControl = "private, no-store";
        return File(data, "image/jpeg");
    }

    /// <summary>Consent: the client agreed at the desk to the processing of the photo for entry.</summary>
    [HttpPut]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(FaceService.MaxFaceBytes + 64 * 1024)]
    public async Task<FaceAccessAdminDto> Upload(Guid clientId, [FromForm] FaceUploadForm form, CancellationToken ct)
    {
        await EnsureClientAsync(clientId, ct);
        await faces.UploadAsync(clientId, form.File, form.Consent, ct);
        return await faces.AdminStatusAsync(clientId, ct);
    }

    [HttpDelete]
    public async Task<FaceAccessAdminDto> Delete(Guid clientId, CancellationToken ct)
    {
        await EnsureClientAsync(clientId, ct);
        await faces.DeleteAsync(clientId, ct);
        return await faces.AdminStatusAsync(clientId, ct);
    }

    private async Task EnsureClientAsync(Guid clientId, CancellationToken ct)
    {
        if (!await db.ClientProfiles.AnyAsync(c => c.Id == clientId, ct)) throw ApiException.NotFound("Client");
    }
}
