using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace FitnessFormulasi.Api.Features.Access;

/// <summary>
/// Unreachable: no answer, timeout or server error. Unauthorized: wrong login or password, or the account is locked.
/// NotSupported: the firmware has no such ISAPI call. Rejected: the device understood the request and refused it.
/// </summary>
public enum IsapiFailure { Unreachable, Unauthorized, NotSupported, Rejected }

public sealed class IsapiException(IsapiFailure failure, string message) : Exception(message)
{
    public IsapiFailure Failure { get; } = failure;
}

public sealed record TerminalInfo(string? Model, string? SerialNumber, string? Firmware, DateTimeOffset? LocalTime);

/// <summary>A person on the terminal. <see cref="From"/>/<see cref="To"/>: club-local days the person may pass.</summary>
public sealed record TerminalUser(string EmployeeNo, string Name, DateOnly From, DateOnly To, int DoorNo);

/// <summary>Creates the HTTP handler for a terminal; replaced in tests by an in-memory terminal.</summary>
public interface IIsapiHandlerFactory
{
    HttpMessageHandler Create(Uri baseUrl, NetworkCredential credential);
}

public sealed class IsapiHandlerFactory : IIsapiHandlerFactory
{
    /// <summary>The terminals use HTTP Digest authentication; the handler answers the challenge itself.</summary>
    public HttpMessageHandler Create(Uri baseUrl, NetworkCredential credential) => new SocketsHttpHandler
    {
        Credentials = new CredentialCache { { baseUrl, "Digest", credential } },
        PreAuthenticate = true,
        ConnectTimeout = TimeSpan.FromSeconds(5),
        PooledConnectionLifetime = TimeSpan.FromMinutes(2),
        AllowAutoRedirect = false,
    };
}

/// <summary>
/// Hikvision ISAPI calls used for face access control on MinMoe terminals (DS-K1T343MFWX and the like): persons with a
/// validity period (<c>/ISAPI/AccessControl/UserInfo/*</c>) and their face photos in face library 1
/// (<c>/ISAPI/Intelligent/FDLib/*</c>). Calls missing in older firmware fall back to their older equivalents.
/// </summary>
public sealed partial class HikvisionTerminal(HttpClient http) : IDisposable
{
    private const string FaceLibrary = """{"faceLibType":"blackFD","FDID":"1","FPID":"{0}"}""";

    public async Task<TerminalInfo> GetInfoAsync(CancellationToken ct)
    {
        var info = XDocument.Parse(await SendForTextAsync(new HttpRequestMessage(HttpMethod.Get, "/ISAPI/System/deviceInfo"), ct));
        DateTimeOffset? time = null;
        try
        {
            var timeXml = XDocument.Parse(await SendForTextAsync(new HttpRequestMessage(HttpMethod.Get, "/ISAPI/System/time"), ct));
            if (DateTimeOffset.TryParse(Element(timeXml, "localTime"), CultureInfo.InvariantCulture, DateTimeStyles.None, out var t)) time = t;
        }
        catch (IsapiException e) when (e.Failure is IsapiFailure.NotSupported or IsapiFailure.Rejected) { }
        return new TerminalInfo(Element(info, "model"), Element(info, "serialNumber"), Element(info, "firmwareVersion"), time);
    }

    public async Task<bool> UserExistsAsync(string employeeNo, CancellationToken ct)
    {
        var body = new JsonObject
        {
            ["UserInfoSearchCond"] = new JsonObject
            {
                ["searchID"] = Guid.NewGuid().ToString("N"),
                ["searchResultPosition"] = 0,
                ["maxResults"] = 1,
                ["EmployeeNoList"] = new JsonArray(new JsonObject { ["employeeNo"] = employeeNo }),
            },
        };
        var result = await SendJsonAsync(HttpMethod.Post, "/ISAPI/AccessControl/UserInfo/Search?format=json", body, ct);
        var search = result?["UserInfoSearch"];
        return search?["numOfMatches"]?.GetValue<int>() > 0;
    }

    /// <summary>Creates the person or updates name and validity period. The person may pass only on those days.</summary>
    public async Task UpsertUserAsync(TerminalUser user, CancellationToken ct)
    {
        var body = new JsonObject
        {
            ["UserInfo"] = new JsonObject
            {
                ["employeeNo"] = user.EmployeeNo,
                ["name"] = user.Name,
                ["userType"] = "normal",
                ["Valid"] = new JsonObject
                {
                    ["enable"] = true,
                    ["beginTime"] = $"{user.From:yyyy-MM-dd}T00:00:00",
                    ["endTime"] = $"{user.To:yyyy-MM-dd}T23:59:59",
                },
                ["doorRight"] = user.DoorNo.ToString(CultureInfo.InvariantCulture),
                ["RightPlan"] = new JsonArray(new JsonObject { ["doorNo"] = user.DoorNo, ["planTemplateNo"] = "1" }),
            },
        };
        if (await UserExistsAsync(user.EmployeeNo, ct))
            await SendJsonAsync(HttpMethod.Put, "/ISAPI/AccessControl/UserInfo/Modify?format=json", body, ct);
        else
            await SendJsonAsync(HttpMethod.Post, "/ISAPI/AccessControl/UserInfo/Record?format=json", body, ct);
    }

    /// <summary>Removes the person together with the face; nothing to do if the person is not there.</summary>
    public async Task DeleteUserAsync(string employeeNo, CancellationToken ct)
    {
        if (!await UserExistsAsync(employeeNo, ct)) return;
        var body = new JsonObject
        {
            ["UserInfoDelCond"] = new JsonObject
            {
                ["EmployeeNoList"] = new JsonArray(new JsonObject { ["employeeNo"] = employeeNo }),
            },
        };
        try
        {
            await SendJsonAsync(HttpMethod.Put, "/ISAPI/AccessControl/UserInfo/Delete?format=json", body, ct);
        }
        catch (IsapiException e) when (e.Failure == IsapiFailure.NotSupported)
        {
            // Newer firmware deletes persons (with their faces and cards) through UserInfoDetail.
            var detail = new JsonObject
            {
                ["UserInfoDetail"] = new JsonObject
                {
                    ["mode"] = "byEmployeeNo",
                    ["EmployeeNoList"] = new JsonArray(new JsonObject { ["employeeNo"] = employeeNo }),
                },
            };
            await SendJsonAsync(HttpMethod.Put, "/ISAPI/AccessControl/UserInfoDetail/Delete?format=json", detail, ct);
        }
    }

    /// <summary>
    /// Sets the person's face photo (JPEG up to 200 KB). The terminal builds the face model on upload and refuses
    /// a photo without a recognisable face (<see cref="IsapiFailure.Rejected"/>).
    /// </summary>
    public async Task SetFaceAsync(string employeeNo, byte[] jpeg, CancellationToken ct)
    {
        try
        {
            // Adds or replaces in one call (newer firmware).
            await SendAsync(new HttpRequestMessage(HttpMethod.Put, "/ISAPI/Intelligent/FDLib/FDSetUp?format=json")
            {
                Content = FaceContent(employeeNo, jpeg),
            }, ct);
            return;
        }
        catch (IsapiException e) when (e.Failure == IsapiFailure.NotSupported) { }

        // Older firmware: remove the previous face, then add the new one.
        try
        {
            var delete = new JsonObject { ["FPID"] = new JsonArray(new JsonObject { ["value"] = employeeNo }) };
            await SendJsonAsync(HttpMethod.Put, "/ISAPI/Intelligent/FDLib/FDSearch/Delete?format=json&FDID=1&faceLibType=blackFD", delete, ct);
        }
        catch (IsapiException e) when (e.Failure is IsapiFailure.Rejected or IsapiFailure.NotSupported) { }
        await SendAsync(new HttpRequestMessage(HttpMethod.Post, "/ISAPI/Intelligent/FDLib/FaceDataRecord?format=json")
        {
            Content = FaceContent(employeeNo, jpeg),
        }, ct);
    }

    /// <summary>
    /// Multipart body as the terminals expect it: quoted part names and an unquoted boundary (some firmware does not
    /// parse a quoted one, which .NET writes by default).
    /// </summary>
    private static MultipartFormDataContent FaceContent(string employeeNo, byte[] jpeg)
    {
        var boundary = "ff" + Guid.NewGuid().ToString("N");
        var content = new MultipartFormDataContent(boundary);
        content.Headers.ContentType = MediaTypeHeaderValue.Parse($"multipart/form-data; boundary={boundary}");

        var record = new StringContent(FaceLibrary.Replace("{0}", employeeNo), Encoding.UTF8);
        record.Headers.ContentType = new MediaTypeHeaderValue("application/json");
        record.Headers.ContentDisposition = new ContentDispositionHeaderValue("form-data") { Name = "\"FaceDataRecord\"" };
        content.Add(record);

        var image = new ByteArrayContent(jpeg);
        image.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        image.Headers.ContentDisposition = new ContentDispositionHeaderValue("form-data") { Name = "\"img\"", FileName = "\"face.jpg\"" };
        content.Add(image);
        return content;
    }

    private async Task<JsonNode?> SendJsonAsync(HttpMethod method, string path, JsonNode body, CancellationToken ct)
    {
        var request = new HttpRequestMessage(method, path)
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        return await SendAsync(request, ct);
    }

    /// <summary>Sends a request and checks the ISAPI ResponseStatus; returns the JSON answer.</summary>
    private async Task<JsonNode?> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var text = await SendForTextAsync(request, ct);
        JsonNode? json = null;
        try { json = JsonNode.Parse(text); }
        catch (JsonException) { }
        var (code, sub, message) = Status(text, json);
        if (code is null or 1) return json;
        if (IsNotSupported(sub)) throw new IsapiException(IsapiFailure.NotSupported, $"Not supported: {sub}");
        throw new IsapiException(IsapiFailure.Rejected, Describe(sub, message, code));
    }

    private async Task<string> SendForTextAsync(HttpRequestMessage request, CancellationToken ct)
    {
        HttpResponseMessage response;
        try { response = await http.SendAsync(request, ct); }
        catch (HttpRequestException e) { throw new IsapiException(IsapiFailure.Unreachable, "No connection: " + e.Message); }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested) { throw new IsapiException(IsapiFailure.Unreachable, "Timed out."); }

        using (response)
        {
            var text = await response.Content.ReadAsStringAsync(ct);
            switch (response.StatusCode)
            {
                case HttpStatusCode.Unauthorized:
                    throw new IsapiException(IsapiFailure.Unauthorized, "Wrong login or password, or the account is locked on the device.");
                case HttpStatusCode.Forbidden:
                    throw new IsapiException(IsapiFailure.Unauthorized, "The device account has no permission for this.");
                case HttpStatusCode.NotFound or HttpStatusCode.MethodNotAllowed or HttpStatusCode.NotImplemented:
                    throw new IsapiException(IsapiFailure.NotSupported, $"Not supported: {request.Method} {request.RequestUri}");
            }
            if ((int)response.StatusCode >= 500) throw new IsapiException(IsapiFailure.Unreachable, $"Device error {(int)response.StatusCode}.");
            // 400 carries a ResponseStatus with the reason; the caller reads it.
            if (!response.IsSuccessStatusCode && response.StatusCode != HttpStatusCode.BadRequest)
                throw new IsapiException(IsapiFailure.Rejected, $"HTTP {(int)response.StatusCode}");
            return text;
        }
    }

    /// <summary>ResponseStatus comes as JSON for <c>format=json</c> calls, as XML otherwise and in some errors.</summary>
    private static (int? Code, string? Sub, string? Message) Status(string text, JsonNode? json)
    {
        if (json is JsonObject obj && obj["statusCode"] is { } codeNode)
        {
            var code = codeNode.GetValueKind() == JsonValueKind.Number ? codeNode.GetValue<int>() : int.TryParse(codeNode.ToString(), out var c) ? c : (int?)null;
            return (code, obj["subStatusCode"]?.ToString(), obj["errorMsg"]?.ToString() ?? obj["statusString"]?.ToString());
        }
        if (json is null && XmlStatusCode().Match(text) is { Success: true } m)
            return (int.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture), XmlSubStatus().Match(text) is { Success: true } s ? s.Groups[1].Value : null, null);
        return (null, null, null);
    }

    private static bool IsNotSupported(string? sub) =>
        sub is not null && (sub.Contains("notSupport", StringComparison.OrdinalIgnoreCase)
                            || sub.Equals("methodNotAllowed", StringComparison.OrdinalIgnoreCase)
                            || sub.Equals("invalidURL", StringComparison.OrdinalIgnoreCase));

    private static string Describe(string? sub, string? message, int? code)
    {
        var text = string.Join(": ", new[] { sub, message }.Where(s => !string.IsNullOrWhiteSpace(s) && s != "ok").Distinct());
        return string.IsNullOrEmpty(text) ? $"Refused by the device (status {code})." : text;
    }

    private static string? Element(XDocument doc, string name) =>
        doc.Descendants().FirstOrDefault(e => e.Name.LocalName == name)?.Value.Trim() is { Length: > 0 } v ? v : null;

    [GeneratedRegex(@"<statusCode>\s*(\d+)\s*</statusCode>")]
    private static partial Regex XmlStatusCode();

    [GeneratedRegex(@"<subStatusCode>\s*([^<\s]+)\s*</subStatusCode>")]
    private static partial Regex XmlSubStatus();

    public void Dispose() => http.Dispose();
}

/// <summary>Opens a connection to a configured terminal.</summary>
public sealed class HikvisionTerminalFactory(IIsapiHandlerFactory handlers)
{
    public HikvisionTerminal Create(string baseUrl, string username, string password)
    {
        var uri = new Uri(baseUrl);
        var http = new HttpClient(handlers.Create(uri, new NetworkCredential(username, password)), disposeHandler: true)
        {
            BaseAddress = uri,
            Timeout = TimeSpan.FromSeconds(30),
        };
        return new HikvisionTerminal(http);
    }
}
