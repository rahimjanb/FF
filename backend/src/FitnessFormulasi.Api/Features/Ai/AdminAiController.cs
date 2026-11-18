using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Features.Integrations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>
/// AI service for the «Питание» section (ChatGPT or Claude): provider, API key, models, monthly budget, connection
/// check. Only administrators marked with <c>CanManageIntegrations</c>. Keys are write-only.
/// </summary>
[ApiController]
[Route("api/admin/ai")]
[Authorize(Policy = Permissions.ManageIntegrations)]
[Produces("application/json")]
public class AdminAiController(AiSettingsService settings) : ControllerBase
{
    [HttpGet]
    public Task<AiSettingsDto> Get(CancellationToken ct) => settings.GetAsync(ct);

    /// <summary>Switch, provider, models and budget. Keys are not accepted here.</summary>
    [HttpPut]
    public Task<AiSettingsDto> Update(UpdateAiSettingsRequest req, CancellationToken ct) => settings.UpdateAsync(req, ct);

    /// <summary>Sets or replaces the API key of a provider ("OpenAI", "Anthropic"). The value is never returned.</summary>
    [HttpPut("keys/{provider}")]
    public Task<AiSettingsDto> SetKey(string provider, SetAiKeyRequest req, CancellationToken ct) =>
        settings.SetKeyAsync(provider, req.Value, ct);

    [HttpDelete("keys/{provider}")]
    public Task<AiSettingsDto> DeleteKey(string provider, CancellationToken ct) => settings.DeleteKeyAsync(provider, ct);

    /// <summary>Makes real requests with the selected provider and models (costs a fraction of a cent).</summary>
    [HttpPost("check")]
    public Task<AiSettingsDto> Check(CancellationToken ct) => settings.CheckAsync(ct);

    [HttpGet("audit")]
    public Task<List<AuditEntryDto>> Audit(CancellationToken ct) => settings.AuditAsync(ct);
}
