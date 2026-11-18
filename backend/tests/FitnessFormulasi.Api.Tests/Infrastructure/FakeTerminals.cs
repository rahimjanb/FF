using System.Collections.Concurrent;
using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Features.Access;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Net.Http.Headers;

namespace FitnessFormulasi.Api.Tests.Infrastructure;

/// <summary>In-memory Hikvision terminals, one per address, answering the ISAPI calls the API makes.</summary>
public sealed class FakeTerminals : IIsapiHandlerFactory
{
    private readonly ConcurrentDictionary<string, FakeTerminal> _terminals = new();

    /// <summary>The terminal at <paramref name="host"/> (e.g. "10.0.0.7"), created on first use.</summary>
    public FakeTerminal At(string host) => _terminals.GetOrAdd(host, _ => new FakeTerminal());

    public HttpMessageHandler Create(Uri baseUrl, NetworkCredential credential) => new Handler(At(baseUrl.Host), credential);

    private sealed class Handler(FakeTerminal terminal, NetworkCredential credential) : HttpMessageHandler
    {
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            if (terminal.Offline) throw new HttpRequestException("Connection refused");
            if (credential.Password != terminal.Password) return new HttpResponseMessage(HttpStatusCode.Unauthorized);
            terminal.Requests.Enqueue($"{request.Method} {request.RequestUri!.AbsolutePath}");
            return await terminal.HandleAsync(request, ct);
        }
    }
}

public sealed class FakeTerminal
{
    public const string FaceRejectMarker = "NOFACE";

    public sealed record User(string Name, string BeginTime, string EndTime, string DoorRight);

    public ConcurrentDictionary<string, User> Users { get; } = new();
    public ConcurrentDictionary<string, byte[]> Faces { get; } = new();
    public ConcurrentQueue<string> Requests { get; } = new();
    public string Password { get; set; } = "Device123";
    public bool Offline { get; set; }
    /// <summary>Older firmware without <c>FDSetUp</c>: faces are added with <c>FaceDataRecord</c>.</summary>
    public bool LegacyFaceApi { get; set; }
    /// <summary>Newer firmware: persons are deleted only through <c>UserInfoDetail/Delete</c>.</summary>
    public bool DetailDeleteOnly { get; set; }

    internal async Task<HttpResponseMessage> HandleAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var path = request.RequestUri!.AbsolutePath;
        var method = request.Method.Method;
        switch (method, path)
        {
            case ("GET", "/ISAPI/System/deviceInfo"):
                return Xml("""<?xml version="1.0" encoding="UTF-8"?><DeviceInfo version="2.0" xmlns="http://www.isapi.org/ver20/XMLSchema"><deviceName>Entrance</deviceName><model>DS-K1T343MFWX</model><serialNumber>DS-K1T343MFWX20240101AAWRF12345678</serialNumber><firmwareVersion>V3.15.0</firmwareVersion></DeviceInfo>""");
            case ("GET", "/ISAPI/System/time"):
                var local = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(5));
                return Xml($"""<?xml version="1.0" encoding="UTF-8"?><Time version="2.0" xmlns="http://www.isapi.org/ver20/XMLSchema"><timeMode>NTP</timeMode><localTime>{local:yyyy-MM-ddTHH:mm:sszzz}</localTime><timeZone>CST-5:00:00</timeZone></Time>""");
            case ("POST", "/ISAPI/AccessControl/UserInfo/Search"):
            {
                var no = (await JsonAsync(request, ct))!["UserInfoSearchCond"]!["EmployeeNoList"]![0]!["employeeNo"]!.GetValue<string>();
                var found = Users.ContainsKey(no);
                return Json(new JsonObject
                {
                    ["UserInfoSearch"] = new JsonObject
                    {
                        ["responseStatusStrg"] = found ? "OK" : "NO MATCH", ["numOfMatches"] = found ? 1 : 0, ["totalMatches"] = found ? 1 : 0,
                    },
                });
            }
            case ("POST", "/ISAPI/AccessControl/UserInfo/Record"):
            case ("PUT", "/ISAPI/AccessControl/UserInfo/Modify"):
            {
                var info = (await JsonAsync(request, ct))!["UserInfo"]!;
                var no = info["employeeNo"]!.GetValue<string>();
                if (method == "POST" && Users.ContainsKey(no)) return Status(6, "employeeNoAlreadyExist");
                if (method == "PUT" && !Users.ContainsKey(no)) return Status(6, "employeeNoNotExist");
                var valid = info["Valid"]!;
                if (valid["enable"]!.GetValue<bool>() != true) return Status(6, "badParameters");
                Users[no] = new User(info["name"]!.GetValue<string>(), valid["beginTime"]!.GetValue<string>(), valid["endTime"]!.GetValue<string>(),
                    info["doorRight"]!.GetValue<string>());
                return Status(1, "ok");
            }
            case ("PUT", "/ISAPI/AccessControl/UserInfo/Delete") when DetailDeleteOnly:
                return Status(4, "notSupport");
            case ("PUT", "/ISAPI/AccessControl/UserInfo/Delete"):
            case ("PUT", "/ISAPI/AccessControl/UserInfoDetail/Delete"):
            {
                var json = (await JsonAsync(request, ct))!;
                var cond = path.EndsWith("UserInfoDetail/Delete") ? json["UserInfoDetail"]! : json["UserInfoDelCond"]!;
                var no = cond["EmployeeNoList"]![0]!["employeeNo"]!.GetValue<string>();
                Users.TryRemove(no, out _);
                Faces.TryRemove(no, out _);
                return Status(1, "ok");
            }
            case ("PUT", "/ISAPI/Intelligent/FDLib/FDSetUp"):
                return LegacyFaceApi ? new HttpResponseMessage(HttpStatusCode.NotFound) : await SetFaceAsync(request, replace: true, ct);
            case ("POST", "/ISAPI/Intelligent/FDLib/FaceDataRecord"):
                return await SetFaceAsync(request, replace: false, ct);
            case ("PUT", "/ISAPI/Intelligent/FDLib/FDSearch/Delete"):
            {
                var no = (await JsonAsync(request, ct))!["FPID"]![0]!["value"]!.GetValue<string>();
                Faces.TryRemove(no, out _);
                return Status(1, "ok");
            }
            default:
                return new HttpResponseMessage(HttpStatusCode.NotFound);
        }
    }

    /// <summary>Checks the multipart format the terminals need: an unquoted boundary and quoted part names.</summary>
    private async Task<HttpResponseMessage> SetFaceAsync(HttpRequestMessage request, bool replace, CancellationToken ct)
    {
        var contentType = request.Content!.Headers.ContentType!.ToString();
        if (!contentType.StartsWith("multipart/form-data; boundary=") || contentType.Contains('"')) return Status(4, "badParameters");
        var boundary = HeaderUtilities.RemoveQuotes(MediaTypeHeaderValue.Parse(contentType).Boundary).Value!;
        var reader = new MultipartReader(boundary, await request.Content.ReadAsStreamAsync(ct));
        string? fpid = null;
        byte[]? image = null;
        while (await reader.ReadNextSectionAsync(ct) is { } section)
        {
            var disposition = section.ContentDisposition ?? "";
            using var buffer = new MemoryStream();
            await section.Body.CopyToAsync(buffer, ct);
            if (disposition.Contains("name=\"FaceDataRecord\""))
            {
                var record = JsonNode.Parse(buffer.ToArray())!;
                if (record["faceLibType"]!.GetValue<string>() != "blackFD" || record["FDID"]!.GetValue<string>() != "1") return Status(4, "badParameters");
                fpid = record["FPID"]!.GetValue<string>();
            }
            else if (disposition.Contains("name=\"img\""))
            {
                image = buffer.ToArray();
            }
        }
        if (fpid is null || image is null) return Status(4, "badParameters");
        if (!Users.ContainsKey(fpid)) return Status(6, "employeeNoNotExist");
        if (!replace && Faces.ContainsKey(fpid)) return Status(6, "deviceUserAlreadyExistFace");
        if (Encoding.ASCII.GetString(image).Contains(FaceRejectMarker)) return Status(6, "faceDataModelingFailed");
        Faces[fpid] = image;
        return Status(1, "ok");
    }

    private static async Task<JsonNode?> JsonAsync(HttpRequestMessage request, CancellationToken ct) =>
        JsonNode.Parse(await request.Content!.ReadAsStringAsync(ct));

    private static HttpResponseMessage Status(int code, string sub) => new(code == 1 ? HttpStatusCode.OK : HttpStatusCode.BadRequest)
    {
        Content = new StringContent(new JsonObject
        {
            ["statusCode"] = code, ["statusString"] = code == 1 ? "OK" : "Device Error", ["subStatusCode"] = sub,
            ["errorCode"] = code == 1 ? 0 : 1610637344, ["errorMsg"] = code == 1 ? "ok" : sub,
        }.ToJsonString(), Encoding.UTF8, "application/json"),
    };

    private static HttpResponseMessage Json(JsonNode body) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
    };

    private static HttpResponseMessage Xml(string body) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(body, Encoding.UTF8, "application/xml"),
    };
}
