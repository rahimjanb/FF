using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features;
using FitnessFormulasi.Api.Features.Access;
using FitnessFormulasi.Api.Tests.Infrastructure;

namespace FitnessFormulasi.Api.Tests;

/// <summary>Pure rules of face access: the days a terminal lets a client in, event parsing, photo checks.</summary>
public class FaceAccessRulesTests
{
    private static readonly DateOnly Today = new(2026, 11, 10);
    private static DateOnly D(int offset) => Today.AddDays(offset);

    private static MembershipSpan Span(int start, int end, MembershipStatus status = MembershipStatus.Active, int? limit = null, int used = 0,
        params (int Start, int End)[] freezes) =>
        new(D(start), D(end), status, limit, used, freezes.Select(f => (D(f.Start), D(f.End))).ToList());

    [Fact]
    public void No_usable_membership_means_no_access()
    {
        Assert.Null(AccessWindowCalculator.Compute([], Today));
        Assert.Null(AccessWindowCalculator.Compute([Span(-40, -11)], Today)); // expired
        Assert.Null(AccessWindowCalculator.Compute([Span(-5, 24, MembershipStatus.Cancelled)], Today));
        Assert.Null(AccessWindowCalculator.Compute([Span(-5, 24, MembershipStatus.Frozen)], Today)); // frozen by staff, no end date
        Assert.Null(AccessWindowCalculator.Compute([Span(-5, 24, limit: 8, used: 8)], Today)); // all visits used
    }

    [Fact]
    public void Active_membership_gives_its_days_and_a_planned_freeze_cuts_them()
    {
        Assert.Equal(new AccessWindow(D(-5), D(24)), AccessWindowCalculator.Compute([Span(-5, 24, limit: 8, used: 3)], Today));
        Assert.Equal(new AccessWindow(D(-5), D(9)), AccessWindowCalculator.Compute([Span(-5, 34, freezes: (10, 19))], Today));
        // Frozen now: the terminal lets the client in again from the day after the freeze.
        Assert.Equal(new AccessWindow(D(3), D(34)), AccessWindowCalculator.Compute([Span(-5, 34, freezes: (-2, 2))], Today));
        // After a past freeze the period starts when it ended.
        Assert.Equal(new AccessWindow(D(-10), D(34)), AccessWindowCalculator.Compute([Span(-30, 34, freezes: (-20, -11))], Today));
    }

    [Fact]
    public void Back_to_back_memberships_join_and_an_upcoming_one_gives_future_days()
    {
        Assert.Equal(new AccessWindow(D(-5), D(54)), AccessWindowCalculator.Compute([Span(25, 54), Span(-5, 24)], Today));
        Assert.Equal(new AccessWindow(D(-5), D(24)), AccessWindowCalculator.Compute([Span(-5, 24), Span(30, 59)], Today));
        Assert.Equal(new AccessWindow(D(3), D(32)), AccessWindowCalculator.Compute([Span(3, 32)], Today));
        // A used-up membership does not bridge to the next one.
        Assert.Equal(new AccessWindow(D(25), D(54)), AccessWindowCalculator.Compute([Span(-5, 24, limit: 4, used: 4), Span(25, 54)], Today));
    }

    [Fact]
    public void Terminal_events_are_parsed_with_the_person_and_time()
    {
        var e = TerminalEvent.Parse("""
            {"ipAddress":"10.0.0.7","dateTime":"2026-11-10T09:15:00+05:00","eventType":"AccessControllerEvent",
             "AccessControllerEvent":{"majorEventType":5,"subEventType":75,"employeeNoString":"1001","serialNo":42,"name":"Ali"}}
            """)!;
        Assert.True(e.IsAccess);
        Assert.True(e.Granted);
        Assert.Equal(("1001", 42L), (e.EmployeeNo, e.SerialNo));
        var tashkent = TimeZoneInfo.FindSystemTimeZoneById("Asia/Tashkent");
        Assert.Equal(new DateTimeOffset(2026, 11, 10, 4, 15, 0, TimeSpan.Zero), e.OccurredAt(tashkent));
        // Without an offset the time is club-local.
        var local = TerminalEvent.Parse("""{"eventType":"AccessControllerEvent","dateTime":"2026-11-10T09:15:00","AccessControllerEvent":{"majorEventType":5,"subEventType":76,"employeeNo":1001}}""")!;
        Assert.Equal(new DateTimeOffset(2026, 11, 10, 4, 15, 0, TimeSpan.Zero), local.OccurredAt(tashkent));
        Assert.False(local.Granted);
        Assert.Equal("1001", local.EmployeeNo);

        var heartbeat = TerminalEvent.Parse("""{"eventType":"heartBeat","dateTime":"2026-11-10T09:15:00+05:00"}""")!;
        Assert.False(heartbeat.IsAccess);
        Assert.Null(TerminalEvent.Parse("not json"));
    }

    [Fact]
    public void Photo_size_is_read_from_the_jpeg_header()
    {
        Assert.Equal((640, 480), FaceService.JpegSize(FaceAccessTests.Jpeg(640, 480, "comment before the frame")));
        Assert.Null(FaceService.JpegSize([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
        Assert.Null(FaceService.JpegSize([0xFF, 0xD8, 0xFF, 0xD9]));
    }

    [Theory]
    [InlineData("192.168.1.64", "http://192.168.1.64")]
    [InlineData(" http://10.0.0.5:8080/ ", "http://10.0.0.5:8080")]
    [InlineData("https://turnstile.club.local", "https://turnstile.club.local")]
    public void Device_address_is_normalized(string raw, string expected) => Assert.Equal(expected, AdminAccessController.NormalizeAddress(raw));

    [Theory]
    [InlineData("ftp://10.0.0.5")]
    [InlineData("http://10.0.0.5/ISAPI")]
    [InlineData("http://admin:pass@10.0.0.5")]
    public void Bad_device_address_is_rejected(string raw) =>
        Assert.Equal("invalid_device_address", Assert.Throws<ApiException>(() => AdminAccessController.NormalizeAddress(raw)).Code);

    [Fact]
    public void Long_names_are_cut_to_what_the_terminal_holds()
    {
        Assert.Equal("Ali Valiev", AccessPlanner.DisplayName("Ali", "Valiev"));
        var cut = AccessPlanner.DisplayName("Александра", "Константинопольская");
        Assert.True(Encoding.UTF8.GetByteCount(cut) <= AccessPlanner.MaxNameBytes);
        Assert.StartsWith("Александра Конс", cut);
    }
}

/// <summary>
/// Face entry end to end: the client's photo goes to the terminal with the membership dates, passes become visits,
/// and the terminal follows freezes, visit limits and deleted photos.
/// </summary>
[Collection(ApiCollection.Name)]
public class FaceAccessTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;
    private const string DevicePassword = "Device123";

    /// <summary>A minimal JPEG: frame header with the size; <paramref name="comment"/> goes into a comment segment.</summary>
    public static byte[] Jpeg(int width = 640, int height = 480, string? comment = null)
    {
        var bytes = new List<byte> { 0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, (byte)'J', (byte)'F', (byte)'I', (byte)'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0 };
        if (comment is not null)
        {
            var c = Encoding.ASCII.GetBytes(comment);
            bytes.AddRange([0xFF, 0xFE, (byte)((c.Length + 2) >> 8), (byte)((c.Length + 2) & 0xFF), .. c]);
        }
        bytes.AddRange([0xFF, 0xC0, 0x00, 0x11, 0x08, (byte)(height >> 8), (byte)height, (byte)(width >> 8), (byte)width, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
        bytes.AddRange([0xFF, 0xD9]);
        return [.. bytes];
    }

    private static MultipartFormDataContent FaceForm(byte[] data, bool consent = true)
    {
        var file = new ByteArrayContent(data);
        file.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        return new MultipartFormDataContent { { file, "file", "face.jpg" }, { new StringContent(consent ? "true" : "false"), "consent" } };
    }

    private static async Task<FaceAccessDto> UploadAsync(HttpClient client, byte[] photo)
    {
        var res = await client.PutAsync("/api/me/face", FaceForm(photo));
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<FaceAccessDto>(Json))!;
    }

    /// <summary>A fresh terminal at a unique address; other tests' terminals are removed so the client status depends on this one only.</summary>
    private async Task<(AccessDeviceDto Device, FakeTerminal Terminal)> OnlyDeviceAsync(HttpClient admin, bool recordsVisits = true)
    {
        foreach (var d in (await admin.GetFromJsonAsync<List<AccessDeviceDto>>("/api/admin/access/devices", Json))!)
            (await admin.DeleteAsync($"/api/admin/access/devices/{d.Id}")).EnsureSuccessStatusCode();
        var host = $"term-{Guid.NewGuid():N}"[..20];
        var res = await admin.PostAsJsonAsync("/api/admin/access/devices",
            new { name = "Вход", address = host, username = "admin", password = DevicePassword, recordsVisits }, Json);
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return ((await res.Content.ReadFromJsonAsync<AccessDeviceDto>(Json))!, factory.Terminals.At(host));
    }

    private static async Task<AccessSyncResultDto> SyncAsync(HttpClient admin, Guid deviceId)
    {
        var res = await admin.PostAsync($"/api/admin/access/devices/{deviceId}/sync", null);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<AccessSyncResultDto>(Json))!;
    }

    private async Task<(HttpClient Client, Guid Id)> ClientAsync(HttpClient admin, int? planDays = 30, int? visitLimit = null)
    {
        var (client, _) = await _s.RegisterClientAsync();
        var id = await _s.ClientIdAsync(client);
        if (planDays is { } days)
        {
            var plan = await _s.CreatePlanAsync(admin, days, visitLimit);
            (await _s.AssignAsync(admin, id, plan.Id)).EnsureSuccessStatusCode();
        }
        return (client, id);
    }

    private static async Task<FaceAccessAdminDto> AdminFaceAsync(HttpClient admin, Guid clientId) =>
        (await admin.GetFromJsonAsync<FaceAccessAdminDto>($"/api/admin/clients/{clientId}/face", Json))!;

    private Task<HttpResponseMessage> PushAsync(string path, string employeeNo, int minor, long serial, DateTimeOffset at, bool multipart = false)
    {
        var json = new JsonObject
        {
            ["ipAddress"] = "10.0.0.7", ["dateTime"] = at.ToOffset(TimeSpan.FromHours(5)).ToString("yyyy-MM-ddTHH:mm:sszzz"),
            ["eventType"] = "AccessControllerEvent",
            ["AccessControllerEvent"] = new JsonObject
            {
                ["majorEventType"] = 5, ["subEventType"] = minor, ["employeeNoString"] = employeeNo, ["serialNo"] = serial, ["name"] = "Test",
            },
        }.ToJsonString();
        HttpContent content = new StringContent(json, Encoding.UTF8, "application/json");
        if (multipart)
        {
            var picture = new ByteArrayContent([0xFF, 0xD8, 0xFF, 0xD9]);
            picture.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
            content = new MultipartFormDataContent { { content, "event_log" }, { picture, "Picture", "picture.jpg" } };
        }
        return factory.CreateClient().PostAsync(path, content);
    }

    [Fact]
    public async Task Client_photo_reaches_the_terminal_with_the_membership_dates_and_passes_become_visits()
    {
        var admin = await factory.AdminAsync();
        var (device, terminal) = await OnlyDeviceAsync(admin);
        var (client, clientId) = await ClientAsync(admin, planDays: null);
        Assert.Equal(FaceAccessStatus.None, (await client.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!.Status);

        // Consent and a JPEG of a sensible size are required.
        async Task<string?> Rejected(HttpContent form) => await Scenario.ErrorCodeAsync(await client.PutAsync("/api/me/face", form));
        Assert.Equal("face_consent_required", await Rejected(FaceForm(Jpeg(), consent: false)));
        Assert.Equal("face_invalid_format", await Rejected(FaceForm([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0])));
        Assert.Equal("face_bad_size", await Rejected(FaceForm(Jpeg(120, 160))));
        Assert.Equal("face_too_large", await Rejected(FaceForm([.. Jpeg(), .. new byte[FaceService.MaxFaceBytes]])));

        // No membership yet: saved, but not sent to the terminal.
        var photo = Jpeg(720, 960, "client-1");
        var saved = await UploadAsync(client, photo);
        Assert.Equal((FaceAccessStatus.Waiting, false), (saved.Status, saved.HasAccess));
        await SyncAsync(admin, device.Id);
        var accessNo = (await AdminFaceAsync(admin, clientId)).AccessNo!.Value.ToString();
        Assert.False(terminal.Users.ContainsKey(accessNo));

        // The membership is assigned: the terminal gets the person with the membership days and the face.
        var plan = await _s.CreatePlanAsync(admin, 30);
        (await _s.AssignAsync(admin, clientId, plan.Id)).EnsureSuccessStatusCode();
        var today = Scenario.Today(factory);
        var pending = (await client.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!;
        Assert.Equal((FaceAccessStatus.Pending, today, today.AddDays(29)), (pending.Status, pending.AccessFrom, pending.AccessTo));

        var report = (await SyncAsync(admin, device.Id)).Report;
        Assert.Null(report.DeviceError);
        Assert.True(report.Written >= 1 && report.FacesUploaded >= 1);
        var user = terminal.Users[accessNo];
        Assert.Equal(("Test Client", $"{today:yyyy-MM-dd}T00:00:00", $"{today.AddDays(29):yyyy-MM-dd}T23:59:59", "1"),
            (user.Name, user.BeginTime, user.EndTime, user.DoorRight));
        Assert.Equal(photo, terminal.Faces[accessNo]);
        Assert.Contains("PUT /ISAPI/Intelligent/FDLib/FDSetUp", terminal.Requests);
        Assert.Equal(FaceAccessStatus.Ready, (await client.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!.Status);

        // A second pass changes nothing on the terminal.
        var again = (await SyncAsync(admin, device.Id)).Report;
        Assert.Equal((0, 0, 0), (again.Written, again.FacesUploaded, again.Remaining));

        // The client sees their own photo; nobody else's is reachable from the app.
        var own = await client.GetAsync("/api/me/face/photo");
        Assert.Equal(photo, await own.Content.ReadAsByteArrayAsync());
        Assert.Contains("no-store", own.Headers.CacheControl!.ToString());
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/admin/clients/{clientId}/face/photo")).StatusCode);

        // Passes reported by the terminal become visits; a repeated delivery is ignored.
        var now = factory.Clock.Now;
        Assert.Equal(HttpStatusCode.OK, (await PushAsync(device.EventPath, accessNo, 75, 1, now)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await PushAsync(device.EventPath, accessNo, 75, 1, now)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await PushAsync(device.EventPath, accessNo, 75, 2, now.AddMinutes(1), multipart: true)).StatusCode);
        var visits = (await client.GetFromJsonAsync<PagedResult<VisitDto>>("/api/me/visits", Json))!.Items;
        var visit = Assert.Single(visits); // the second pass a minute later is the same visit
        Assert.Equal(VisitSource.FaceTerminal, visit.Source);
        var journal = (await admin.GetFromJsonAsync<PagedResult<AccessEventDto>>($"/api/admin/access/events?clientId={clientId}", Json))!.Items;
        Assert.Equal(2, journal.Count);
        Assert.All(journal, e => Assert.Equal((true, visit.Id, "Вход"), (e.Granted, e.VisitId, e.DeviceName)));

        // A refusal and an unknown person are journaled without visits; a heartbeat only marks the device alive.
        (await PushAsync(device.EventPath, accessNo, 76, 3, now.AddMinutes(30))).EnsureSuccessStatusCode();
        (await PushAsync(device.EventPath, "999999", 75, 4, now.AddMinutes(31))).EnsureSuccessStatusCode();
        (await factory.CreateClient().PostAsync(device.EventPath, new StringContent("""{"eventType":"heartBeat"}""", Encoding.UTF8, "application/json")))
            .EnsureSuccessStatusCode();
        Assert.Single((await client.GetFromJsonAsync<PagedResult<VisitDto>>("/api/me/visits", Json))!.Items);
        var all = (await admin.GetFromJsonAsync<PagedResult<AccessEventDto>>($"/api/admin/access/events?deviceId={device.Id}", Json))!.Items;
        Assert.Contains(all, e => e is { Granted: false, Minor: 76 } && e.Client!.Id == clientId);
        Assert.Contains(all, e => e is { EmployeeNo: "999999", Client: null, Note: "unknown_person" });
        Assert.NotNull((await admin.GetFromJsonAsync<AccessDeviceDto>($"/api/admin/access/devices/{device.Id}", Json))!.LastEventAt);
        Assert.Equal(HttpStatusCode.NotFound, (await PushAsync("/api/access/hikvision/events/wrong-token", accessNo, 75, 5, now)).StatusCode);

        // Deleting the photo removes the client from the terminal.
        var deleted = await client.DeleteAsync("/api/me/face");
        Assert.Equal(FaceAccessStatus.None, (await deleted.Content.ReadFromJsonAsync<FaceAccessDto>(Json))!.Status);
        Assert.True((await SyncAsync(admin, device.Id)).Report.Removed >= 1);
        Assert.False(terminal.Users.ContainsKey(accessNo));
        Assert.False(terminal.Faces.ContainsKey(accessNo));
    }

    [Fact]
    public async Task Terminal_follows_freezes_and_removes_a_client_after_the_last_visit_of_the_plan()
    {
        var admin = await factory.AdminAsync();
        var (device, terminal) = await OnlyDeviceAsync(admin);
        var today = Scenario.Today(factory);

        // A planned freeze ends the terminal period the day before it starts.
        var (frozen, frozenId) = await ClientAsync(admin, planDays: 180);
        await UploadAsync(frozen, Jpeg(comment: "frozen"));
        var membership = (await frozen.GetFromJsonAsync<List<MembershipDto>>("/api/me/memberships", Json))!.Single();
        (await frozen.PostAsJsonAsync($"/api/me/memberships/{membership.Id}/freeze",
            new { startDate = today.AddDays(10), endDate = today.AddDays(19) }, Json)).EnsureSuccessStatusCode();
        await SyncAsync(admin, device.Id);
        var frozenNo = (await AdminFaceAsync(admin, frozenId)).AccessNo!.Value.ToString();
        Assert.Equal($"{today.AddDays(9):yyyy-MM-dd}T23:59:59", terminal.Users[frozenNo].EndTime);

        // Cancelling the freeze gives the whole period back.
        (await frozen.PostAsync($"/api/me/memberships/{membership.Id}/unfreeze", null)).EnsureSuccessStatusCode();
        await SyncAsync(admin, device.Id);
        Assert.Equal($"{membership.EndDate:yyyy-MM-dd}T23:59:59", terminal.Users[frozenNo].EndTime);

        // One-visit plan: after the pass the client is taken off the terminal (newer firmware deletes via UserInfoDetail).
        var (limited, limitedId) = await ClientAsync(admin, planDays: 30, visitLimit: 1);
        await UploadAsync(limited, Jpeg(comment: "limited"));
        await SyncAsync(admin, device.Id);
        var limitedNo = (await AdminFaceAsync(admin, limitedId)).AccessNo!.Value.ToString();
        Assert.True(terminal.Users.ContainsKey(limitedNo));
        (await PushAsync(device.EventPath, limitedNo, 75, 100, factory.Clock.Now)).EnsureSuccessStatusCode();
        terminal.DetailDeleteOnly = true;
        await SyncAsync(admin, device.Id);
        Assert.False(terminal.Users.ContainsKey(limitedNo));
        Assert.Contains("PUT /ISAPI/AccessControl/UserInfoDetail/Delete", terminal.Requests);
        var status = (await limited.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!;
        Assert.Equal((FaceAccessStatus.Waiting, false), (status.Status, status.HasAccess));

        // An exit terminal does not record visits.
        var (exit, _) = await OnlyDeviceAsync(admin, recordsVisits: false);
        await SyncAsync(admin, exit.Id);
        (await PushAsync(exit.EventPath, frozenNo, 75, 1, factory.Clock.Now)).EnsureSuccessStatusCode();
        Assert.Empty((await frozen.GetFromJsonAsync<PagedResult<VisitDto>>("/api/me/visits", Json))!.Items);
    }

    [Fact]
    public async Task Refused_photo_older_firmware_and_an_unreachable_terminal_are_reported_and_recovered()
    {
        var admin = await factory.AdminAsync();
        var (device, terminal) = await OnlyDeviceAsync(admin);
        terminal.LegacyFaceApi = true;

        // The terminal finds no face: the client is asked for a new photo, the admin sees why.
        var (client, clientId) = await ClientAsync(admin);
        await UploadAsync(client, Jpeg(comment: FakeTerminal.FaceRejectMarker));
        var first = (await SyncAsync(admin, device.Id)).Report;
        Assert.Equal(1, first.Failed);
        Assert.Equal(FaceAccessStatus.Rejected, (await client.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!.Status);
        var issue = Assert.Single((await admin.GetFromJsonAsync<List<AccessIssueDto>>($"/api/admin/access/devices/{device.Id}/issues", Json))!);
        Assert.Equal((clientId, AccessSyncState.PhotoRejected), (issue.ClientId, issue.State));
        Assert.Contains("faceDataModelingFailed", issue.LastError);
        Assert.Equal(1, (await admin.GetFromJsonAsync<AccessDeviceDto>($"/api/admin/access/devices/{device.Id}", Json))!.Stats.PhotoRejected);
        // The same photo is not sent again.
        Assert.Equal(0, (await SyncAsync(admin, device.Id)).Report.FacesUploaded);

        // A new photo goes through the older face API (FaceDataRecord).
        var good = Jpeg(comment: "retake");
        await UploadAsync(client, good);
        Assert.Equal(1, (await SyncAsync(admin, device.Id)).Report.FacesUploaded);
        var accessNo = (await AdminFaceAsync(admin, clientId)).AccessNo!.Value.ToString();
        Assert.Equal(good, terminal.Faces[accessNo]);
        Assert.Contains("POST /ISAPI/Intelligent/FDLib/FaceDataRecord", terminal.Requests);
        Assert.Equal(FaceAccessStatus.Ready, (await client.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!.Status);

        // The terminal is unreachable: the pass stops, the admin panel shows the error, nothing is lost.
        terminal.Offline = true;
        var (second, secondId) = await ClientAsync(admin);
        await UploadAsync(second, Jpeg(comment: "second"));
        var offline = await SyncAsync(admin, device.Id);
        Assert.Contains("No connection", offline.Report.DeviceError);
        Assert.Contains("No connection", offline.Device.LastError);
        Assert.Equal(FaceAccessStatus.Pending, (await second.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!.Status);
        Assert.Equal(AccessSyncState.Pending, (await AdminFaceAsync(admin, secondId)).Devices.Single().State);

        // While it is unreachable, the first client deletes the photo and takes a new one: the terminal gets the new one.
        (await client.DeleteAsync("/api/me/face")).EnsureSuccessStatusCode();
        var newer = Jpeg(comment: "after-delete");
        Assert.True((await UploadAsync(client, newer)).Version > 1);

        terminal.Offline = false;
        var online = await SyncAsync(admin, device.Id);
        Assert.Null(online.Device.LastError);
        Assert.Equal(FaceAccessStatus.Ready, (await second.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!.Status);
        Assert.Equal(newer, terminal.Faces[accessNo]);
    }

    [Fact]
    public async Task Staff_upload_photos_at_the_desk_and_manage_terminals_without_exposing_the_password()
    {
        var admin = await factory.AdminAsync();
        Assert.Equal("invalid_device_address", await Scenario.ErrorCodeAsync(await admin.PostAsJsonAsync("/api/admin/access/devices",
            new { name = "X", address = "http://10.0.0.5/ISAPI", username = "admin", password = "p" }, Json)));
        Assert.Equal("device_password_required", await Scenario.ErrorCodeAsync(await admin.PostAsJsonAsync("/api/admin/access/devices",
            new { name = "X", address = "10.0.0.5", username = "admin" }, Json)));

        var (device, terminal) = await OnlyDeviceAsync(admin);
        Assert.True(device.HasPassword);
        Assert.StartsWith("/api/access/hikvision/events/", device.EventPath);
        var raw = await admin.GetStringAsync($"/api/admin/access/devices/{device.Id}");
        Assert.DoesNotContain(DevicePassword, raw);

        var check = (await (await admin.PostAsync($"/api/admin/access/devices/{device.Id}/check", null)).Content
            .ReadFromJsonAsync<AccessDeviceCheckDto>(Json))!;
        Assert.True(check.Ok);
        Assert.Equal(("DS-K1T343MFWX", "V3.15.0", true), (check.Device.Model, check.Device.Firmware, check.TimeZoneMatches));

        // A wrong password is reported as such; the saved one is kept when the field is left empty.
        terminal.Password = "Changed123";
        var wrong = (await (await admin.PostAsync($"/api/admin/access/devices/{device.Id}/check", null)).Content
            .ReadFromJsonAsync<AccessDeviceCheckDto>(Json))!;
        Assert.False(wrong.Ok);
        Assert.Contains("password", wrong.Error);
        var updated = await admin.PutAsJsonAsync($"/api/admin/access/devices/{device.Id}", new
        {
            name = "Вход 2", address = device.BaseUrl, username = "admin", password = "Changed123",
            isActive = true, recordsVisits = true, doorNo = 1,
        }, Json);
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal("Вход 2", (await updated.Content.ReadFromJsonAsync<AccessDeviceDto>(Json))!.Name);
        Assert.True((await (await admin.PostAsync($"/api/admin/access/devices/{device.Id}/check", null)).Content
            .ReadFromJsonAsync<AccessDeviceCheckDto>(Json))!.Ok);

        // The desk takes the photo with the client's consent.
        var (client, clientId) = await ClientAsync(admin);
        Assert.Equal("face_consent_required", await Scenario.ErrorCodeAsync(
            await admin.PutAsync($"/api/admin/clients/{clientId}/face", FaceForm(Jpeg(), consent: false))));
        var res = await admin.PutAsync($"/api/admin/clients/{clientId}/face", FaceForm(Jpeg(comment: "desk")));
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var face = (await res.Content.ReadFromJsonAsync<FaceAccessAdminDto>(Json))!;
        Assert.Equal(FaceAccessStatus.Pending, face.Status);
        Assert.NotNull(face.UploadedBy);
        Assert.NotNull(face.ConsentAt);
        await SyncAsync(admin, device.Id);
        var synced = await AdminFaceAsync(admin, clientId);
        Assert.Equal(FaceAccessStatus.Ready, synced.Status);
        Assert.Equal(AccessSyncState.Synced, synced.Devices.Single().State);
        Assert.Equal(Jpeg(comment: "desk"), await admin.GetByteArrayAsync($"/api/admin/clients/{clientId}/face/photo"));
        Assert.Equal(FaceAccessStatus.Ready, (await client.GetFromJsonAsync<FaceAccessDto>("/api/me/face", Json))!.Status);

        // Clients have no access to terminals; secrets never reach the logs.
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/admin/access/devices")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/admin/access/events")).StatusCode);
        Assert.DoesNotContain(factory.Logs.Lines, l => l.Contains(DevicePassword) || l.Contains("Changed123"));
    }
}
