namespace FitnessFormulasi.Api.Common;

/// <summary>Expected business error. Converted to RFC 7807 ProblemDetails with a stable machine-readable code.</summary>
public class ApiException(int statusCode, string code, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
    public string Code { get; } = code;

    public static ApiException NotFound(string what) => new(StatusCodes.Status404NotFound, "not_found", $"{what} not found.");
    public static ApiException Conflict(string code, string message) => new(StatusCodes.Status409Conflict, code, message);
    public static ApiException BadRequest(string code, string message) => new(StatusCodes.Status400BadRequest, code, message);
    public static ApiException Forbidden(string message = "Access denied.") => new(StatusCodes.Status403Forbidden, "forbidden", message);
    public static ApiException Unauthorized(string code, string message) => new(StatusCodes.Status401Unauthorized, code, message);
}
