using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Admin;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Banners;

public class SaveBannerRequest
{
    [Required, StringLength(120, MinimumLength = 1)] public string Title { get; set; } = "";
    [StringLength(4000)] public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
}

public class ReorderRequest
{
    /// <summary>Ids in the new order. Ids not listed keep their place after the listed ones.</summary>
    [Required] public List<Guid> Ids { get; set; } = [];
}

/// <summary>Banners for the app home screen: text, photos and videos. Media files are saved as soon as they are uploaded.</summary>
[ApiController]
[Route("api/admin/banners")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminBannersController(AppDbContext db, MediaStorage storage) : ControllerBase
{
    public const int MaxMediaPerBanner = 20;
    private const int UploadOverhead = 64 * 1024;

    [HttpGet]
    public async Task<List<BannerAdminDto>> List(CancellationToken ct)
    {
        var banners = await db.Banners.AsNoTracking().Include(b => b.Media)
            .OrderBy(b => b.SortOrder).ThenByDescending(b => b.CreatedAt).ToListAsync(ct);
        return banners.Select(BannerMapping.ToAdminDto).ToList();
    }

    [HttpGet("{id:guid}")]
    public async Task<BannerAdminDto> Get(Guid id, CancellationToken ct) => BannerMapping.ToAdminDto(await LoadAsync(id, ct));

    /// <summary>New banners go first in the carousel; add photos and videos with <see cref="UploadMedia"/>.</summary>
    [HttpPost]
    public async Task<ActionResult<BannerAdminDto>> Create(SaveBannerRequest req, CancellationToken ct)
    {
        var first = await db.Banners.MinAsync(b => (int?)b.SortOrder, ct) ?? 1;
        var banner = new Banner { Title = req.Title.Trim(), Description = AdminClientsController.Clean(req.Description), IsActive = req.IsActive, SortOrder = first - 1 };
        db.Banners.Add(banner);
        await db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(Get), new { id = banner.Id }, BannerMapping.ToAdminDto(banner));
    }

    [HttpPut("{id:guid}")]
    public async Task<BannerAdminDto> Update(Guid id, SaveBannerRequest req, CancellationToken ct)
    {
        var banner = await LoadAsync(id, ct, tracking: true);
        banner.Title = req.Title.Trim();
        banner.Description = AdminClientsController.Clean(req.Description);
        banner.IsActive = req.IsActive;
        await db.SaveChangesAsync(ct);
        return BannerMapping.ToAdminDto(banner);
    }

    /// <summary>Deletes the banner with its photos and videos.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var banner = await LoadAsync(id, ct, tracking: true);
        var files = banner.Media.Select(m => m.Id).ToList();
        db.Banners.Remove(banner);
        await db.SaveChangesAsync(ct);
        files.ForEach(storage.Delete);
        return NoContent();
    }

    /// <summary>Sets the carousel order.</summary>
    [HttpPut("order")]
    public async Task<List<BannerAdminDto>> Reorder(ReorderRequest req, CancellationToken ct)
    {
        var banners = await db.Banners.ToListAsync(ct);
        ApplyOrder(banners, b => b.Id, b => b.SortOrder, (b, i) => b.SortOrder = i, req.Ids);
        await db.SaveChangesAsync(ct);
        return await List(ct);
    }

    /// <summary>
    /// Adds a photo (JPEG, PNG, WebP up to 10 MB) or a video (MP4, MOV up to 100 MB) at the end of the gallery.
    /// The format is checked by content. The first photo of the gallery is the banner cover.
    /// </summary>
    [HttpPost("{id:guid}/media")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MediaFormats.MaxVideoBytes + UploadOverhead)]
    [RequestFormLimits(MultipartBodyLengthLimit = MediaFormats.MaxVideoBytes + UploadOverhead)]
    public async Task<BannerAdminDto> UploadMedia(Guid id, IFormFile file, CancellationToken ct)
    {
        var banner = await LoadAsync(id, ct, tracking: true);
        if (banner.Media.Count >= MaxMediaPerBanner)
            throw ApiException.Conflict("banner_media_limit", $"A banner may have at most {MaxMediaPerBanner} photos and videos.");

        var head = new byte[MediaFormats.HeaderBytes];
        int read;
        await using (var probe = file.OpenReadStream())
            read = await probe.ReadAtLeastAsync(head, head.Length, throwOnEndOfStream: false, ct);
        var format = MediaFormats.Detect(head.AsSpan(0, read))
                     ?? throw ApiException.BadRequest("media_invalid_format", "Only JPEG, PNG, WebP photos and MP4, MOV videos are accepted.");
        var limit = format.Kind == BannerMediaKind.Image ? MediaFormats.MaxImageBytes : MediaFormats.MaxVideoBytes;
        if (file.Length == 0 || file.Length > limit)
            throw ApiException.BadRequest("media_too_large", format.Kind == BannerMediaKind.Image
                ? "A photo must be up to 10 MB." : "A video must be up to 100 MB.");

        var media = new BannerMedia
        {
            BannerId = id,
            Kind = format.Kind,
            ContentType = format.ContentType,
            SizeBytes = file.Length,
            SortOrder = banner.Media.Count == 0 ? 0 : banner.Media.Max(m => m.SortOrder) + 1,
        };
        await using (var content = file.OpenReadStream())
            await storage.SaveAsync(media.Id, content, ct);
        try
        {
            db.BannerMedia.Add(media);
            await db.SaveChangesAsync(ct);
        }
        catch
        {
            storage.Delete(media.Id);
            throw;
        }
        return BannerMapping.ToAdminDto(banner);
    }

    [HttpDelete("{id:guid}/media/{mediaId:guid}")]
    public async Task<BannerAdminDto> DeleteMedia(Guid id, Guid mediaId, CancellationToken ct)
    {
        var banner = await LoadAsync(id, ct, tracking: true);
        var media = banner.Media.SingleOrDefault(m => m.Id == mediaId) ?? throw ApiException.NotFound("Media");
        banner.Media.Remove(media);
        db.BannerMedia.Remove(media);
        await db.SaveChangesAsync(ct);
        storage.Delete(mediaId);
        return BannerMapping.ToAdminDto(banner);
    }

    /// <summary>Sets the gallery order; moving a photo first makes it the cover.</summary>
    [HttpPut("{id:guid}/media/order")]
    public async Task<BannerAdminDto> ReorderMedia(Guid id, ReorderRequest req, CancellationToken ct)
    {
        var banner = await LoadAsync(id, ct, tracking: true);
        ApplyOrder(banner.Media.ToList(), m => m.Id, m => m.SortOrder, (m, i) => m.SortOrder = i, req.Ids);
        await db.SaveChangesAsync(ct);
        return BannerMapping.ToAdminDto(banner);
    }

    private async Task<Banner> LoadAsync(Guid id, CancellationToken ct, bool tracking = false)
    {
        var q = db.Banners.Include(b => b.Media).Where(b => b.Id == id);
        return await (tracking ? q : q.AsNoTracking()).SingleOrDefaultAsync(ct) ?? throw ApiException.NotFound("Banner");
    }

    /// <summary>Numbers the listed items 0..n in the given order, then the rest in their current order.</summary>
    private static void ApplyOrder<T>(List<T> items, Func<T, Guid> id, Func<T, int> order, Action<T, int> set, List<Guid> ids)
    {
        var position = ids.Distinct().Select((x, i) => (x, i)).ToDictionary(p => p.x, p => p.i);
        if (position.Keys.Any(k => items.All(item => id(item) != k)))
            throw ApiException.BadRequest("unknown_id", "The order lists an id that does not belong here.");
        var sorted = items.OrderBy(item => position.TryGetValue(id(item), out var p) ? p : int.MaxValue).ThenBy(order).ToList();
        for (var i = 0; i < sorted.Count; i++) set(sorted[i], i);
    }
}
