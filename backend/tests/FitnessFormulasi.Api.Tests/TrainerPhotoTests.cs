using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

[Collection(ApiCollection.Name)]
public class TrainerPhotoTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4];

    private static MultipartFormDataContent Form(byte[] data, string name = "photo.png")
    {
        var file = new ByteArrayContent(data);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
        return new MultipartFormDataContent { { file, "file", name } };
    }

    [Fact]
    public async Task Admin_uploads_photo_clients_see_its_url_and_anyone_can_load_it()
    {
        var admin = await factory.AdminAsync();
        var (_, trainer) = await _s.CreateTrainerAsync(admin);
        Assert.Null(trainer.PhotoUrl);

        var res = await admin.PutAsync($"/api/admin/trainers/{trainer.Id}/photo", Form(Png));
        res.EnsureSuccessStatusCode();
        var updated = (await res.Content.ReadFromJsonAsync<TrainerAdminDto>(Json))!;
        Assert.Equal($"/api/trainers/{trainer.Id}/photo?v=1", updated.PhotoUrl);

        var (client, _) = await _s.RegisterClientAsync();
        var seen = (await client.GetFromJsonAsync<TrainerPublicDto>($"/api/trainers/{trainer.Id}", Json))!;
        Assert.Equal(updated.PhotoUrl, seen.PhotoUrl);

        var image = await factory.CreateClient().GetAsync(updated.PhotoUrl);
        Assert.Equal(HttpStatusCode.OK, image.StatusCode);
        Assert.Equal("image/png", image.Content.Headers.ContentType!.MediaType);
        Assert.Equal(Png, await image.Content.ReadAsByteArrayAsync());

        // A new upload changes the URL; deleting removes it.
        (await admin.PutAsync($"/api/admin/trainers/{trainer.Id}/photo", Form(Png))).EnsureSuccessStatusCode();
        var deleted = await admin.DeleteAsync($"/api/admin/trainers/{trainer.Id}/photo");
        Assert.Null((await deleted.Content.ReadFromJsonAsync<TrainerAdminDto>(Json))!.PhotoUrl);
        Assert.Equal(HttpStatusCode.NotFound, (await factory.CreateClient().GetAsync($"/api/trainers/{trainer.Id}/photo")).StatusCode);
    }

    [Fact]
    public async Task Non_images_are_rejected_by_content_and_only_admin_can_upload()
    {
        var admin = await factory.AdminAsync();
        var (trainerHttp, trainer) = await _s.CreateTrainerAsync(admin);

        var fake = await admin.PutAsync($"/api/admin/trainers/{trainer.Id}/photo", Form("<svg/>"u8.ToArray(), "photo.png"));
        Assert.Equal(HttpStatusCode.BadRequest, fake.StatusCode);
        Assert.Equal("photo_invalid_format", await Scenario.ErrorCodeAsync(fake));

        var big = new byte[2 * 1024 * 1024 + 1];
        Png.CopyTo(big, 0);
        var tooBig = await admin.PutAsync($"/api/admin/trainers/{trainer.Id}/photo", Form(big));
        Assert.Equal(HttpStatusCode.BadRequest, tooBig.StatusCode);

        var self = await trainerHttp.PutAsync($"/api/admin/trainers/{trainer.Id}/photo", Form(Png));
        Assert.Equal(HttpStatusCode.Forbidden, self.StatusCode);
    }
}
