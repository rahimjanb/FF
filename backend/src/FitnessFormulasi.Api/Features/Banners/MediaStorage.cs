using FitnessFormulasi.Api.Domain;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Banners;

public sealed class MediaOptions
{
    public const string Section = "Media";

    /// <summary>Folder for uploaded banner photos and videos. Defaults to <c>App_Data/media</c> under the content root.</summary>
    public string? RootPath { get; set; }
}

/// <summary>
/// Uploaded media files on the local disk, one file per media id. Videos are too large for the database, so the
/// files live here and must be backed up together with it (docs/OPERATIONS.md).
/// </summary>
public sealed class MediaStorage
{
    private readonly string _root;

    public MediaStorage(IOptions<MediaOptions> options, IWebHostEnvironment env)
    {
        var configured = options.Value.RootPath;
        _root = Path.GetFullPath(string.IsNullOrWhiteSpace(configured)
            ? Path.Combine(env.ContentRootPath, "App_Data", "media")
            : configured);
        Directory.CreateDirectory(_root);
    }

    public string PathFor(Guid id) => Path.Combine(_root, id.ToString("N"));

    public bool Exists(Guid id) => File.Exists(PathFor(id));

    /// <summary>Writes to a temporary file first, so a failed upload never leaves a truncated file under the id.</summary>
    public async Task SaveAsync(Guid id, Stream content, CancellationToken ct)
    {
        var path = PathFor(id);
        var temp = path + ".part";
        try
        {
            await using (var file = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true))
                await content.CopyToAsync(file, ct);
            File.Move(temp, path, overwrite: true);
        }
        catch
        {
            File.Delete(temp);
            throw;
        }
    }

    /// <summary>Best effort: a file left behind only wastes disk space, it is never served without its database row.</summary>
    public void Delete(Guid id)
    {
        try { File.Delete(PathFor(id)); }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}

/// <summary>Accepted upload formats, recognised by the file content rather than its name or the browser's type.</summary>
public static class MediaFormats
{
    public const int MaxImageBytes = 10 * 1024 * 1024;
    public const int MaxVideoBytes = 100 * 1024 * 1024;
    public const int HeaderBytes = 16;

    // ISO base media brands that are still images (HEIC/AVIF), not videos.
    private static readonly HashSet<string> ImageBrands = ["heic", "heix", "hevc", "heim", "heis", "mif1", "msf1", "avif", "avis"];

    /// <summary>JPEG, PNG, WebP photos; MP4 and QuickTime (MOV) videos, the formats phones record and play.</summary>
    public static (BannerMediaKind Kind, string ContentType)? Detect(ReadOnlySpan<byte> head)
    {
        if (head is [0xFF, 0xD8, 0xFF, ..]) return (BannerMediaKind.Image, "image/jpeg");
        if (head is [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ..]) return (BannerMediaKind.Image, "image/png");
        if (head is [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ..]) return (BannerMediaKind.Image, "image/webp");
        if (head.Length >= 12 && head[4..8].SequenceEqual("ftyp"u8))
        {
            var brand = System.Text.Encoding.ASCII.GetString(head[8..12]);
            if (ImageBrands.Contains(brand)) return null;
            return (BannerMediaKind.Video, brand == "qt  " ? "video/quicktime" : "video/mp4");
        }
        return null;
    }

    /// <summary>File extension for URLs: players such as AVPlayer pick the decoder by it as well as by the content type.</summary>
    public static string Extension(string contentType) => contentType switch
    {
        "image/jpeg" => "jpg",
        "image/png" => "png",
        "image/webp" => "webp",
        "video/quicktime" => "mov",
        _ => "mp4",
    };
}
