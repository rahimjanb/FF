namespace FitnessFormulasi.Api.Auth;

/// <summary>
/// Fine-grained permissions on top of roles. They are read from the database on every request
/// (JwtBearer OnTokenValidated), so granting or revoking takes effect immediately.
/// </summary>
public static class Permissions
{
    public const string ClaimType = "ff:permission";

    /// <summary>View and change payment integration settings. Requires the Admin role and User.CanManageIntegrations.</summary>
    public const string ManageIntegrations = "manage_integrations";
}
