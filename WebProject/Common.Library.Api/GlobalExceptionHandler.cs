using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Common.Library.Api;

internal sealed class GlobalExceptionHandler(
    IHostEnvironment env,
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (statusCode, title) = exception switch
        {
            TimeoutException => (StatusCodes.Status408RequestTimeout, "Request Timeout"),
            NotImplementedException => (StatusCodes.Status501NotImplemented, "Not Implemented"),
            _ => (StatusCodes.Status500InternalServerError, "An unexpected error occurred"),
        };

        if (statusCode >= 500)
            logger.LogError(exception, "Unhandled {ExceptionType}: {Message}", exception.GetType().Name,
                exception.Message);
        else
            logger.LogWarning(exception, "Handled {ExceptionType}: {Message}", exception.GetType().Name,
                exception.Message);

        httpContext.Response.StatusCode = statusCode;

        var problem = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Type = $"https://httpstatuses.io/{statusCode}",
            Detail = env.IsDevelopment() ? exception.Message : null,
        };

        await httpContext.Response.WriteAsJsonAsync(problem, cancellationToken);

        return true;
    }
}