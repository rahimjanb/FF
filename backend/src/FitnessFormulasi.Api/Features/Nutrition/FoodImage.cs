using System.Security.Cryptography;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Features.Access;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>
/// Checks an uploaded food photo and removes its metadata. The app sends a JPEG already scaled to ≤ 1568 px (the
/// size vision models work at); the server accepts JPEG only, recognised by its content, up to
/// <see cref="MaxBytes"/>, <see cref="MinSide"/>–<see cref="MaxSide"/> px. EXIF/XMP/IPTC segments (GPS position,
/// camera serial, time) are stripped before the photo is stored or sent to the AI service.
/// </summary>
public static class FoodImage
{
    public const int MaxBytes = 6 * 1024 * 1024;
    public const int MinSide = 320;
    public const int MaxSide = 4096;

    public sealed record Checked(byte[] Jpeg, int Width, int Height, string Sha256);

    public static async Task<Checked> ReadAsync(IFormFile? file, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            throw ApiException.BadRequest("photo_invalid_format", "Attach a JPEG photo.");
        if (file.Length > MaxBytes)
            throw ApiException.BadRequest("photo_too_large", $"The photo must be a JPEG of up to {MaxBytes / 1024 / 1024} MB.");
        using var buffer = new MemoryStream((int)file.Length);
        await file.CopyToAsync(buffer, ct);
        return Check(buffer.ToArray());
    }

    public static Checked Check(byte[] data)
    {
        if (FaceService.JpegSize(data) is not { } size)
            throw ApiException.BadRequest("photo_invalid_format", "Only JPEG photos are accepted.");
        if (Math.Min(size.Width, size.Height) < MinSide || Math.Max(size.Width, size.Height) > MaxSide)
            throw ApiException.BadRequest("photo_bad_size", $"The photo must be from {MinSide} to {MaxSide} pixels on each side.");
        var clean = StripMetadata(data);
        return new Checked(clean, size.Width, size.Height, Convert.ToHexStringLower(SHA256.HashData(clean)));
    }

    /// <summary>
    /// Copies the JPEG without APP1 (EXIF, XMP), APP13 (IPTC/Photoshop) and COM segments. Everything from the start
    /// of scan on is copied as is. Image data and colour profile (APP2) are untouched.
    /// </summary>
    public static byte[] StripMetadata(byte[] d)
    {
        if (d.Length < 4 || d[0] != 0xFF || d[1] != 0xD8) return d;
        using var output = new MemoryStream(d.Length);
        output.Write(d, 0, 2);
        var i = 2;
        while (i + 3 < d.Length)
        {
            if (d[i] != 0xFF) break; // not a marker: leave the rest as it is
            var marker = d[i + 1];
            if (marker == 0xFF) { i++; continue; }
            if (marker is 0x01 or (>= 0xD0 and <= 0xD7)) { output.Write(d, i, 2); i += 2; continue; }
            if (marker == 0xDA || marker == 0xD9) break; // start of scan / end of image: copy the rest
            var length = (d[i + 2] << 8) | d[i + 3];
            if (length < 2 || i + 2 + length > d.Length) break;
            var drop = marker is 0xE1 or 0xED or 0xFE;
            if (!drop) output.Write(d, i, 2 + length);
            i += 2 + length;
        }
        output.Write(d, i, d.Length - i);
        return output.ToArray();
    }
}
