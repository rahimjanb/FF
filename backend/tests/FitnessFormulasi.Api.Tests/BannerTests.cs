using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Banners;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

/// <summary>Home screen banners: managed in the admin panel with photos and videos, shown to clients in the app.</summary>
[Collection(ApiCollection.Name)]
public class BannerTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4, 5, 6, 7, 8];

    /// <summary>Start of an MP4 file: a "ftyp" box with the isom brand, then some payload.</summary>
    private static readonly byte[] Mp4 = [0, 0, 0, 0x18, (byte)'f', (byte)'t', (byte)'y', (byte)'p', (byte)'i', (byte)'s', (byte)'o', (byte)'m',
        0, 0, 2, 0, .. Enumerable.Range(0, 200).Select(i => (byte)i)];

    private static readonly byte[] Heic = [0, 0, 0, 0x18, (byte)'f', (byte)'t', (byte)'y', (byte)'p', (byte)'h', (byte)'e', (byte)'i', (byte)'c', 0, 0, 0, 0];

    private static MultipartFormDataContent Form(byte[] data, string name)
    {
        var file = new ByteArrayContent(data);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
        return new MultipartFormDataContent { { file, "file", name } };
    }

    private static async Task<BannerAdminDto> CreateAsync(HttpClient admin, string title, bool active = true)
    {
        var res = await admin.PostAsJsonAsync("/api/admin/banners", new { title, description = "Скидка 20% до конца месяца", isActive = active }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<BannerAdminDto>(Json))!;
    }

    private static async Task<BannerAdminDto> UploadAsync(HttpClient admin, Guid bannerId, byte[] data, string name)
    {
        var res = await admin.PostAsync($"/api/admin/banners/{bannerId}/media", Form(data, name));
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<BannerAdminDto>(Json))!;
    }

    [Fact]
    public async Task Admin_creates_a_banner_with_photo_and_video_and_clients_see_active_banners_in_order()
    {
        var admin = await factory.AdminAsync();
        var title = "Акция " + Guid.NewGuid().ToString("N")[..6];
        var banner = await CreateAsync(admin, title);
        var hidden = await CreateAsync(admin, title + " скрытый", active: false);

        // A video first: the cover is still the first photo.
        await UploadAsync(admin, banner.Id, Mp4, "promo.mp4");
        var withMedia = await UploadAsync(admin, banner.Id, Png, "cover.png");
        Assert.Equal(new[] { BannerMediaKind.Video, BannerMediaKind.Image }, withMedia.Media.Select(m => m.Kind));
        Assert.Equal("video/mp4", withMedia.Media[0].ContentType);
        Assert.EndsWith(".mp4", withMedia.Media[0].Url);
        Assert.Equal(withMedia.Media[1].Url, withMedia.CoverUrl);

        var (client, _) = await _s.RegisterClientAsync();
        var seen = (await client.GetFromJsonAsync<List<BannerDto>>("/api/banners", Json))!;
        var mine = Assert.Single(seen, b => b.Id == banner.Id);
        Assert.DoesNotContain(seen, b => b.Id == hidden.Id);
        Assert.Equal("Скидка 20% до конца месяца", mine.Description);
        Assert.Equal(withMedia.CoverUrl, mine.CoverUrl);
        Assert.Equal(2, mine.Media.Count);

        // Newest first; the admin can change the carousel order.
        var order = (await (await admin.PutAsJsonAsync("/api/admin/banners/order", new { ids = new[] { banner.Id, hidden.Id } }, Json))
            .Content.ReadFromJsonAsync<List<BannerAdminDto>>(Json))!;
        Assert.True(order.FindIndex(b => b.Id == banner.Id) < order.FindIndex(b => b.Id == hidden.Id));

        // Files load without a token; videos support range requests for streaming.
        var anonymous = factory.CreateClient();
        var image = await anonymous.GetAsync(mine.CoverUrl);
        Assert.Equal(HttpStatusCode.OK, image.StatusCode);
        Assert.Equal("image/png", image.Content.Headers.ContentType?.MediaType);
        Assert.Equal(Png, await image.Content.ReadAsByteArrayAsync());
        var range = new HttpRequestMessage(HttpMethod.Get, mine.Media[0].Url);
        range.Headers.Range = new RangeHeaderValue(0, 9);
        var part = await anonymous.SendAsync(range);
        Assert.Equal(HttpStatusCode.PartialContent, part.StatusCode);
        Assert.Equal(Mp4[..10], await part.Content.ReadAsByteArrayAsync());

        // Moving the photo first, deleting the video.
        var reordered = (await (await admin.PutAsJsonAsync($"/api/admin/banners/{banner.Id}/media/order",
            new { ids = new[] { withMedia.Media[1].Id } }, Json)).Content.ReadFromJsonAsync<BannerAdminDto>(Json))!;
        Assert.Equal(BannerMediaKind.Image, reordered.Media[0].Kind);
        var videoUrl = reordered.Media[1].Url;
        var afterDelete = (await (await admin.DeleteAsync($"/api/admin/banners/{banner.Id}/media/{reordered.Media[1].Id}"))
            .Content.ReadFromJsonAsync<BannerAdminDto>(Json))!;
        Assert.Single(afterDelete.Media);
        Assert.Equal(HttpStatusCode.NotFound, (await anonymous.GetAsync(videoUrl)).StatusCode);

        // Editing and deleting the banner.
        var edited = await admin.PutAsJsonAsync($"/api/admin/banners/{banner.Id}", new { title = title + "!", description = (string?)null, isActive = false }, Json);
        Assert.Equal(HttpStatusCode.OK, edited.StatusCode);
        Assert.DoesNotContain((await client.GetFromJsonAsync<List<BannerDto>>("/api/banners", Json))!, b => b.Id == banner.Id);
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"/api/admin/banners/{banner.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await anonymous.GetAsync(mine.CoverUrl)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await admin.GetAsync($"/api/admin/banners/{banner.Id}")).StatusCode);
        Assert.DoesNotContain(Directory.GetFiles(factory.MediaRoot), f => withMedia.Media.Any(m => f.Contains(m.Id.ToString("N"))));
    }

    [Fact]
    public async Task Uploads_are_checked_by_content_and_size_and_only_admins_manage_banners()
    {
        var admin = await factory.AdminAsync();
        var banner = await CreateAsync(admin, "Проверка " + Guid.NewGuid().ToString("N")[..6]);
        async Task<string?> Upload(byte[] data, string name) =>
            await Scenario.ErrorCodeAsync(await admin.PostAsync($"/api/admin/banners/{banner.Id}/media", Form(data, name)));

        Assert.Equal("media_invalid_format", await Upload("hello"u8.ToArray(), "photo.jpg"));
        Assert.Equal("media_invalid_format", await Upload(Heic, "photo.heic"));
        byte[] bigJpeg = [0xFF, 0xD8, 0xFF, .. new byte[MediaFormats.MaxImageBytes]];
        Assert.Equal("media_too_large", await Upload(bigJpeg, "big.jpg"));
        Assert.Equal("validation_failed", await Scenario.ErrorCodeAsync(
            await admin.PostAsJsonAsync("/api/admin/banners", new { title = "" }, Json)));

        var (client, _) = await _s.RegisterClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/admin/banners")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsync($"/api/admin/banners/{banner.Id}/media", Form(Png, "p.png"))).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync("/api/banners")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await factory.CreateClient().GetAsync("/api/banners/media/not-a-guid.png")).StatusCode);
    }
}
