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
    /// <summary>
    /// The AI service that analyses food photos, named on the privacy page. Empty: the provider in use right now (set in
    /// the admin panel or Ai:Provider), so the page follows a switch between ChatGPT and Claude by itself.
    /// </summary>
    public string? AiProcessor { get; set; }
}

/// <summary>
/// Privacy policy and account deletion instructions: public pages for the store listings (Google Play requires a web
/// page where users can ask for deletion without the app). Russian and Uzbek on one page.
/// </summary>
[ApiController]
[Route("legal")]
[AllowAnonymous]
[ApiExplorerSettings(IgnoreApi = true)]
public class LegalController(IOptions<LegalOptions> options, Features.Ai.AiConnectionProvider ai) : ControllerBase
{
    private static readonly ConcurrentDictionary<string, string> Templates = new();

    [HttpGet("privacy")]
    public async Task<ContentResult> Privacy(CancellationToken ct) => Page("privacy", await AiProcessorAsync(ct));

    [HttpGet("delete-account")]
    public async Task<ContentResult> DeleteAccount(CancellationToken ct) => Page("delete-account", await AiProcessorAsync(ct));

    private async Task<string?> AiProcessorAsync(CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(options.Value.AiProcessor)) return options.Value.AiProcessor;
        var connection = await ai.GetAsync(ct);
        return connection.IsConfigured ? Features.Ai.AiProviders.Find(connection.Provider)?.LegalName ?? connection.DisplayName : null;
    }

    private ContentResult Page(string name, string? aiProcessor)
    {
        var o = options.Value;
        var html = Templates.GetOrAdd(name, Load)
            .Replace("{{OperatorName}}", Encode(o.OperatorName))
            .Replace("{{Address}}", Encode(o.Address))
            .Replace("{{Phone}}", Encode(o.Phone))
            .Replace("{{Email}}", Encode(o.Email))
            .Replace("{{Telegram}}", Encode(o.Telegram))
            .Replace("{{UpdatedOn}}", Encode(o.UpdatedOn))
            .Replace("{{AiProcessor}}", Encode(aiProcessor));
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
