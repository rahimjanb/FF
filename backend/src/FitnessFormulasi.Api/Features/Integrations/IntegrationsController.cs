using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitnessFormulasi.Api.Features.Integrations;

/// <summary>
/// Payment integration settings (Click, Payme). Only administrators marked with <c>CanManageIntegrations</c>.
/// Stage 1 stores and checks settings only: no payment endpoints are exposed and no payments are accepted.
/// </summary>
[ApiController]
[Route("api/admin/integrations")]
[Authorize(Policy = Permissions.ManageIntegrations)]
[Produces("application/json")]
public class IntegrationsController(IntegrationSettingsService settings) : ControllerBase
{
    [HttpGet]
    public Task<List<IntegrationDto>> List(CancellationToken ct) => settings.ListAsync(ct);

    [HttpGet("{provider}")]
    public Task<IntegrationDto> Get(IntegrationProvider provider, CancellationToken ct) => settings.GetAsync(provider, ct);

    /// <summary>Saves switch, mode and non-secret fields. Secrets are not accepted here and are never cleared by this call.</summary>
    [HttpPut("{provider}")]
    public Task<IntegrationDto> Update(IntegrationProvider provider, UpdateIntegrationRequest req, CancellationToken ct) =>
        settings.UpdateAsync(provider, req, ct);

    /// <summary>Sets or replaces one secret of a mode (explicit action). The value is never returned.</summary>
    [HttpPut("{provider}/{mode}/secrets/{name}")]
    public Task<IntegrationDto> SetSecret(IntegrationProvider provider, IntegrationMode mode, string name, SetSecretRequest req,
        CancellationToken ct) => settings.SetSecretAsync(provider, mode, name, req.Value, ct);

    [HttpDelete("{provider}/{mode}/secrets/{name}")]
    public Task<IntegrationDto> DeleteSecret(IntegrationProvider provider, IntegrationMode mode, string name, CancellationToken ct) =>
        settings.DeleteSecretAsync(provider, mode, name, ct);

    [HttpGet("{provider}/audit")]
    public Task<List<AuditEntryDto>> Audit(IntegrationProvider provider, CancellationToken ct) => settings.AuditAsync(provider, ct);
}
