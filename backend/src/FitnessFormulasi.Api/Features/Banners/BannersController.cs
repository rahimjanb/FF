using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Banners;

public record BannerMediaDto(Guid Id, BannerMediaKind Kind, string ContentType, long SizeBytes, string Url);

/// <summary>What the app shows: <c>CoverUrl</c> is the first photo, <c>Media</c> the gallery opened by a tap.</summary>
public record BannerDto(Guid Id, string Title, string? Description, string? CoverUrl, List<BannerMediaDto> Media);

public record BannerAdminDto(
    Guid Id, string Title, string? Description, bool IsActive, int SortOrder, string? CoverUrl, List<BannerMediaDto> Media,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

public static class BannerMapping
{
    /// <summary>The extension lets video players recognise the format; the id alone identifies the file.</summary>
    public static string MediaUrl(BannerMedia m) => $"/api/banners/media/{m.Id}.{MediaFormats.Extension(m.ContentType)}";

    public static List<BannerMediaDto> Media(Banner b) => b.Media.OrderBy(m => m.SortOrder).ThenBy(m => m.CreatedAt)
        .Select(m => new BannerMediaDto(m.Id, m.Kind, m.ContentType, m.SizeBytes, MediaUrl(m))).ToList();

    public static string? CoverUrl(List<BannerMediaDto> media) => media.FirstOrDefault(m => m.Kind == BannerMediaKind.Image)?.Url;

    public static BannerDto ToDto(Banner b)
    {
        var media = Media(b);
        return new BannerDto(b.Id, b.Title, b.Description, CoverUrl(media), media);
    }

    public static BannerAdminDto ToAdminDto(Banner b)
    {
        var media = Media(b);
        return new BannerAdminDto(b.Id, b.Title, b.Description, b.IsActive, b.SortOrder, CoverUrl(media), media, b.CreatedAt, b.UpdatedAt);
    }
}

/// <summary>Banners for the client app home screen.</summary>
[ApiController]
[Route("api/banners")]
[Authorize]
[Produces("application/json")]
public class BannersController(AppDbContext db, MediaStorage storage) : ControllerBase
{
    /// <summary>Banners switched on in the admin panel, in carousel order.</summary>
    [HttpGet]
    public async Task<List<BannerDto>> List(CancellationToken ct)
    {
        var banners = await db.Banners.AsNoTracking().Include(b => b.Media).Where(b => b.IsActive)
            .OrderBy(b => b.SortOrder).ThenByDescending(b => b.CreatedAt).ToListAsync(ct);
        return banners.Select(BannerMapping.ToDto).ToList();
    }

    /// <summary>
    /// Photo or video file, e.g. <c>/api/banners/media/{id}.mp4</c>. Anonymous like trainer photos, so image and video
    /// widgets can load it without a bearer token; the ids are random and the content is club advertising. Supports
    /// range requests, which video players need to seek and stream. A media id never changes its file, so it is cached for long.
    /// </summary>
    [HttpGet("media/{file}")]
    [AllowAnonymous]
    [Produces("image/jpeg", "image/png", "image/webp", "video/mp4", "video/quicktime")]
    public async Task<IActionResult> Media(string file, CancellationToken ct)
    {
        if (!Guid.TryParse(Path.GetFileNameWithoutExtension(file), out var id)) throw ApiException.NotFound("Media");
        var media = await db.BannerMedia.AsNoTracking().Where(m => m.Id == id).Select(m => new { m.ContentType }).SingleOrDefaultAsync(ct);
        if (media is null || !storage.Exists(id)) throw ApiException.NotFound("Media");
        Response.Headers.CacheControl = "public, max-age=31536000, immutable";
        return PhysicalFile(storage.PathFor(id), media.ContentType, enableRangeProcessing: true);
    }
}
