using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace FitnessFormulasi.Api.Common;

/// <summary>Maps exceptions to ProblemDetails. Unexpected errors never leak internals to the client.</summary>
public sealed class ApiExceptionHandler(IProblemDetailsService problemDetails, ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception exception, CancellationToken ct)
    {
        var (status, code, title) = exception switch
        {
            ApiException api => (api.StatusCode, api.Code, api.Message),
            DbUpdateException { InnerException: PostgresException { SqlState: PostgresErrorCodes.UniqueViolation } } =>
                (StatusCodes.Status409Conflict, "conflict", "The record conflicts with an existing one."),
            DbUpdateConcurrencyException =>
                (StatusCodes.Status409Conflict, "concurrency_conflict", "The record was modified by someone else. Reload and try again."),
            BadHttpRequestException bad => (bad.StatusCode, "bad_request", "The request is malformed."),
            _ => (StatusCodes.Status500InternalServerError, "internal_error", "An unexpected error occurred."),
        };

        if (status >= 500)
            logger.LogError(exception, "Unhandled exception for {Method} {Path}", http.Request.Method, http.Request.Path);
        else
            logger.LogInformation("Request failed with {Status} {Code} for {Method} {Path}", status, code, http.Request.Method, http.Request.Path);

        http.Response.StatusCode = status;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = http,
            Exception = exception,
            ProblemDetails = new ProblemDetails
            {
                Status = status,
                Title = title,
                Extensions = { ["code"] = code },
            },
        });
    }
}

public static class ErrorHandlingExtensions
{
    public static IServiceCollection AddApiErrorHandling(this IServiceCollection services)
    {
        services.AddProblemDetails(o => o.CustomizeProblemDetails = ctx =>
        {
            ctx.ProblemDetails.Instance = ctx.HttpContext.Request.Path;
            ctx.ProblemDetails.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
            if (!ctx.ProblemDetails.Extensions.ContainsKey("code"))
            {
                ctx.ProblemDetails.Extensions["code"] = ctx.ProblemDetails.Status switch
                {
                    400 => "validation_failed",
                    401 => "unauthorized",
                    403 => "forbidden",
                    404 => "not_found",
                    429 => "too_many_requests",
                    _ => "error",
                };
            }
        });
        services.AddExceptionHandler<ApiExceptionHandler>();
        return services;
    }
}
