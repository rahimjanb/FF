using System.Text.RegularExpressions;
using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features.Integrations;

/// <summary>A merchant credential field. All fields are required for a provider to count as configured.</summary>
public sealed record IntegrationField(string Name, bool IsSecret, Regex Format);

/// <summary>
/// Merchant credentials each provider needs, per its official documentation:
/// Click SHOP API (Prepare/Complete) and Payme Merchant API (JSON-RPC). Test and production modes use separate values.
/// </summary>
public static partial class IntegrationCatalog
{
    public static readonly IReadOnlyDictionary<IntegrationProvider, IReadOnlyList<IntegrationField>> Fields =
        new Dictionary<IntegrationProvider, IReadOnlyList<IntegrationField>>
        {
            // Issued by Click when the service is connected; secret_key signs Prepare/Complete (sign_string).
            [IntegrationProvider.Click] =
            [
                new("serviceId", false, Digits()),
                new("merchantId", false, Digits()),
                new("merchantUserId", false, Digits()),
                new("secretKey", true, SecretFormat()),
            ],
            // Cash register (kassa) id from the Payme Business cabinet, and its key: "TEST_KEY" for the sandbox,
            // "key" for production. The key authenticates Payme's requests (HTTP Basic, login "Paycom").
            [IntegrationProvider.Payme] =
            [
                new("merchantId", false, PaymeMerchantId()),
                new("key", true, SecretFormat()),
            ],
        };

    public static IntegrationField? Find(IntegrationProvider provider, string name) =>
        Fields[provider].FirstOrDefault(f => f.Name == name);

    [GeneratedRegex(@"^\d{1,12}$")]
    private static partial Regex Digits();

    [GeneratedRegex(@"^[0-9a-f]{24}$")]
    private static partial Regex PaymeMerchantId();

    [GeneratedRegex(@"^\S{8,256}$")]
    private static partial Regex SecretFormat();
}
