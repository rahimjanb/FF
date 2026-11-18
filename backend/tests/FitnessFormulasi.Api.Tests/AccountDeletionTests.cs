using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Features.Access;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace FitnessFormulasi.Api.Tests;

[Collection(ApiCollection.Name)]
public class AccountDeletionTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;

    private static MultipartFormDataContent FaceForm()
    {
        var file = new ByteArrayContent(FaceAccessTests.Jpeg());
        file.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        return new MultipartFormDataContent { { file, "file", "face.jpg" }, { new StringContent("true"), "consent" } };
    }

    private Task<HttpResponseMessage> DeleteOwnAsync(HttpClient client, string password) =>
        client.PostAsJsonAsync("/api/me/delete-account", new { password }, Json);

    [Fact]
    public async Task Client_deletes_the_account_in_the_app_personal_data_is_erased_and_records_stay()
    {
        var admin = await factory.AdminAsync();
        foreach (var d in (await admin.GetFromJsonAsync<List<AccessDeviceDto>>("/api/admin/access/devices", Json))!)
            (await admin.DeleteAsync($"/api/admin/access/devices/{d.Id}")).EnsureSuccessStatusCode();
        var host = $"del-{Guid.NewGuid():N}"[..20];
        var created = await admin.PostAsJsonAsync("/api/admin/access/devices",
            new { name = "Вход", address = host, username = "admin", password = "Device123", recordsVisits = true }, Json);
        var device = (await created.Content.ReadFromJsonAsync<AccessDeviceDto>(Json))!;
        var terminal = factory.Terminals.At(host);

        var phone = ApiFactory.NewPhone();
        var (client, auth) = await _s.RegisterClientAsync(phone);
        var clientId = await _s.ClientIdAsync(client);
        var plan = await _s.CreatePlanAsync(admin);
        (await _s.AssignAsync(admin, clientId, plan.Id)).EnsureSuccessStatusCode();
        (await client.PutAsync("/api/me/face", FaceForm())).EnsureSuccessStatusCode();
        (await admin.PostAsync($"/api/admin/access/devices/{device.Id}/sync", null)).EnsureSuccessStatusCode();
        var employeeNo = (await admin.GetFromJsonAsync<FaceAccessAdminDto>($"/api/admin/clients/{clientId}/face", Json))!.AccessNo.ToString()!;
        Assert.True(terminal.Faces.ContainsKey(employeeNo)); // other tests' clients may be on the terminal too

        Assert.Equal("invalid_password", await Scenario.ErrorCodeAsync(await DeleteOwnAsync(client, "Wrong12345")));
        Assert.Equal(HttpStatusCode.NoContent, (await DeleteOwnAsync(client, Scenario.Password)).StatusCode);

        // Signed out everywhere, and the phone number and password no longer sign in.
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/me/profile")).StatusCode);
        var refresh = await factory.CreateClient().PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken }, Json);
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
        var login = await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { phone, password = Scenario.Password }, Json);
        Assert.Equal("invalid_credentials", await Scenario.ErrorCodeAsync(login));

        var dto = (await admin.GetFromJsonAsync<ClientAdminDto>($"/api/admin/clients/{clientId}", Json))!;
        Assert.Equal(UserStatus.Deleted, dto.Status);
        Assert.NotNull(dto.DeletedAt);
        Assert.Equal((AccountDeletionService.DeletedFirstName, AccountDeletionService.DeletedLastName), (dto.FirstName, dto.LastName));
        Assert.StartsWith("del-", dto.Phone);
        Assert.Null(dto.Email);
        Assert.Null(dto.BirthDate);
        // The membership stays for the club's accounting (cancelled); the face photo is gone and the terminal forgets the person.
        var kept = Assert.Single((await admin.GetFromJsonAsync<List<MembershipDto>>($"/api/admin/clients/{clientId}/memberships", Json))!);
        Assert.Equal(MembershipEffectiveStatus.Cancelled, kept.EffectiveStatus); // the unused rest is lost
        Assert.Null(dto.CurrentMembership);
        Assert.Equal(FaceAccessStatus.None, (await admin.GetFromJsonAsync<FaceAccessAdminDto>($"/api/admin/clients/{clientId}/face", Json))!.Status);
        (await admin.PostAsync($"/api/admin/access/devices/{device.Id}/sync", null)).EnsureSuccessStatusCode();
        Assert.False(terminal.Users.ContainsKey(employeeNo));
        Assert.False(terminal.Faces.ContainsKey(employeeNo));

        // Hidden from the client list unless asked for.
        var list = (await admin.GetFromJsonAsync<PagedResult<ClientAdminDto>>("/api/admin/clients?pageSize=100", Json))!;
        Assert.DoesNotContain(list.Items, c => c.Id == clientId);
        var deleted = (await admin.GetFromJsonAsync<PagedResult<ClientAdminDto>>("/api/admin/clients?status=Deleted&pageSize=100", Json))!;
        Assert.Contains(deleted.Items, c => c.Id == clientId);

        // Nothing can be done with the account any more.
        Assert.Equal("client_deleted", await Scenario.ErrorCodeAsync(await admin.PostAsync($"/api/admin/clients/{clientId}/delete", null)));
        Assert.Equal("client_deleted", await Scenario.ErrorCodeAsync(await _s.AssignAsync(admin, clientId, plan.Id, Scenario.Today(factory).AddDays(60))));
        Assert.Equal("client_deleted", await Scenario.ErrorCodeAsync(
            await admin.PostAsJsonAsync($"/api/admin/clients/{clientId}/reset-password", new { newPassword = "Temp12345" }, Json)));
        Assert.Equal("client_deleted", await Scenario.ErrorCodeAsync(await admin.PutAsJsonAsync($"/api/admin/clients/{clientId}",
            new { phone = ApiFactory.NewPhone(), firstName = "A", lastName = "B", status = "Active" }, Json)));
        Assert.Equal("client_deleted", await Scenario.ErrorCodeAsync(await admin.PutAsync($"/api/admin/clients/{clientId}/face", FaceForm())));

        // The phone number is free for a new registration.
        await _s.RegisterClientAsync(phone);
    }

    [Fact]
    public async Task Staff_deletes_the_account_on_request_open_requests_and_future_sessions_are_cancelled()
    {
        var admin = await factory.AdminAsync();
        var (trainer, t) = await _s.CreateTrainerAsync(admin);
        var (client, _) = await _s.RegisterClientAsync();
        var clientId = await _s.ClientIdAsync(client);
        var accepted = await _s.RequestTrainerAsync(client, t.Id);
        (await trainer.PostAsJsonAsync($"/api/trainer/requests/{accepted.Id}/accept", new { }, Json)).EnsureSuccessStatusCode();
        var session = await trainer.PostAsJsonAsync("/api/trainer/sessions",
            new { clientId, startsAt = factory.Clock.Now.AddDays(2), durationMinutes = 60 }, Json);
        Assert.Equal(HttpStatusCode.Created, session.StatusCode);
        var (_, other) = await _s.CreateTrainerAsync(admin);
        await _s.RequestTrainerAsync(client, other.Id);
        var plan = await _s.CreatePlanAsync(admin);
        (await client.PostAsJsonAsync("/api/me/membership-requests", new { planId = plan.Id, kind = "New" }, Json)).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.NoContent, (await admin.PostAsync($"/api/admin/clients/{clientId}/delete", null)).StatusCode);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Null((await db.ClientProfiles.SingleAsync(c => c.Id == clientId)).AssignedTrainerId);
        Assert.All(await db.TrainerRequests.Where(r => r.ClientProfileId == clientId).ToListAsync(), r =>
        {
            Assert.Null(r.Message);
            Assert.NotEqual(TrainerRequestStatus.Pending, r.Status);
        });
        Assert.All(await db.MembershipRequests.Where(r => r.ClientProfileId == clientId).ToListAsync(),
            r => Assert.Equal(MembershipRequestStatus.Cancelled, r.Status));
        Assert.All(await db.TrainingSessions.Where(s => s.ClientProfileId == clientId).ToListAsync(),
            s => Assert.Equal(TrainingSessionStatus.Cancelled, s.Status));
        Assert.Contains(await db.AuditLog.Where(a => a.Target == $"client:{clientId}").ToListAsync(), a => a.Action == "client.deleted");
    }

    [Fact]
    public async Task Legal_pages_are_public_html_with_the_club_details_filled_in()
    {
        var http = factory.CreateClient();
        foreach (var path in new[] { "/legal/privacy", "/legal/delete-account" })
        {
            var res = await http.GetAsync(path);
            Assert.Equal(HttpStatusCode.OK, res.StatusCode);
            Assert.Equal("text/html", res.Content.Headers.ContentType?.MediaType);
            var html = await res.Content.ReadAsStringAsync();
            Assert.DoesNotContain("{{", html);
            Assert.Contains("ООО &quot;Fitness &lt;Test&gt;&quot;", html); // configured in ApiFactory, HTML-encoded
            Assert.Contains("Fitness Formulasi", html);
        }
    }
}
