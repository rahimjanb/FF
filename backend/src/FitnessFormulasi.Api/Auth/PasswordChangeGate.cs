using FitnessFormulasi.Api.Common;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.Infrastructure;

namespace FitnessFormulasi.Api.Auth;

/// <summary>Marks endpoints a user may call while their password is still the temporary one set by staff.</summary>
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public sealed class AllowWithPendingPasswordChangeAttribute : Attribute;

/// <summary>
/// Blocks every other endpoint with 403 <c>password_change_required</c> until the user replaces a temporary password.
/// The flag is read once per request in JwtBearer OnTokenValidated (see Program.cs).
/// </summary>
public sealed class PasswordChangeGate(ProblemDetailsFactory problems) : IAsyncAuthorizationFilter
{
    public const string ItemKey = "ff.mustChangePassword";

    public Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var http = context.HttpContext;
        if (http.Items[ItemKey] is not true) return Task.CompletedTask;
        if (context.ActionDescriptor.EndpointMetadata.OfType<AllowWithPendingPasswordChangeAttribute>().Any()) return Task.CompletedTask;

        var problem = problems.CreateProblemDetails(http, StatusCodes.Status403Forbidden, "Change your temporary password to continue.");
        problem.Extensions["code"] = "password_change_required";
        context.Result = new ObjectResult(problem) { StatusCode = StatusCodes.Status403Forbidden, ContentTypes = { "application/problem+json" } };
        return Task.CompletedTask;
    }
}
