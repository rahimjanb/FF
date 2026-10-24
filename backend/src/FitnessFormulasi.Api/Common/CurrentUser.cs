using System.Security.Claims;

namespace FitnessFormulasi.Api.Common;

public interface ICurrentUser
{
    Guid Id { get; }
    bool IsInRole(string role);
}

public sealed class HttpCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private ClaimsPrincipal Principal => accessor.HttpContext?.User ?? throw new InvalidOperationException("No HTTP context.");

    public Guid Id => Guid.TryParse(Principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
        ? id
        : throw ApiException.Unauthorized("unauthorized", "Authentication required.");

    public bool IsInRole(string role) => Principal.IsInRole(role);
}
