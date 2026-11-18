using System.Collections.Concurrent;
using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Legal;

/// <summary>
/// The club's details on the public legal pages. App Store and Google Play link to these pages, so they must be filled
/// before the app is submitted (<c>Legal__OperatorName</c> and so on); an empty value is shown as "—".
/// </summary>
public sealed class LegalOptions
{
    public const string Section = "Legal";

    /// <summary>Legal entity that runs the club and processes the data, e.g. «ООО "…"».</summary>
    public string? OperatorName { get; set; }
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? Telegram { get; set; }
    /// <summary>Date of the current text of the pages; change it when the text changes.</summary>
    public string UpdatedOn { get; set; } = "18.11.2026";
    /// <summary>The AI service that analyses food photos (the Ai:Provider in use), named on the privacy page.</summary>
    public string AiProcessor { get; set; } = "Anthropic PBC (США), сервис Claude";
}

/// <summary>
/// Privacy policy and account deletion instructions: public pages for the store listings (Google Play requires a web
/// page where users can ask for deletion without the app). Russian and Uzbek on one page.
/// </summary>
[ApiController]
[Route("legal")]
[AllowAnonymous]
[ApiExplorerSettings(IgnoreApi = true)]
public class LegalController(IOptions<LegalOptions> options) : ControllerBase
{
    private static readonly ConcurrentDictionary<string, string> Templates = new();

    [HttpGet("privacy")]
    public ContentResult Privacy() => Page("privacy");

    [HttpGet("delete-account")]
    public ContentResult DeleteAccount() => Page("delete-account");

    private ContentResult Page(string name)
    {
        var o = options.Value;
        var html = Templates.GetOrAdd(name, Load)
            .Replace("{{OperatorName}}", Encode(o.OperatorName))
            .Replace("{{Address}}", Encode(o.Address))
            .Replace("{{Phone}}", Encode(o.Phone))
            .Replace("{{Email}}", Encode(o.Email))
            .Replace("{{Telegram}}", Encode(o.Telegram))
            .Replace("{{UpdatedOn}}", Encode(o.UpdatedOn))
            .Replace("{{AiProcessor}}", Encode(o.AiProcessor));
        Response.Headers.CacheControl = "public, max-age=3600";
        Response.Headers.XContentTypeOptions = "nosniff";
        Response.Headers.ContentSecurityPolicy =
            "default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
        return Content(html, "text/html; charset=utf-8");
    }

    private static string Load(string name)
    {
        using var stream = typeof(LegalController).Assembly.GetManifestResourceStream($"legal/{name}.html")
                           ?? throw new InvalidOperationException($"Legal page template '{name}' is not embedded.");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }

    private static string Encode(string? value) => string.IsNullOrWhiteSpace(value) ? "—" : WebUtility.HtmlEncode(value.Trim());
}
