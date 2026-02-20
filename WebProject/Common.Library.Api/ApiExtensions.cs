using System.Text.Json;
using System.Text.Json.Serialization;
using Common.Library.Logging;
using FastEndpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi;

namespace Common.Library.Api;

public static class ApiExtensions
{
    extension(WebApplicationBuilder builder)
    {
        /// <summary>
        /// Registers all common API services: Serilog, JSON options, controllers,
        /// FastEndpoints, OpenAPI, ProblemDetails, and CORS.
        /// Call this after <c>builder.AddServiceDefaults()</c>.
        /// </summary>
        public WebApplicationBuilder AddApiDefaults()
        {
            builder.AddSerilogLogging();

            builder.Services.Configure<JsonOptions>(o =>
            {
                o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
                o.SerializerOptions.PropertyNameCaseInsensitive = true;
                o.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
            });

            builder.Services.AddControllers();
            builder.Services.AddFastEndpoints();
            builder.Services.AddOpenApi(o => o.OpenApiVersion = OpenApiSpecVersion.OpenApi3_0);
            builder.Services.AddProblemDetails();
            builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

            builder.Services.AddCors(c =>
                c.AddDefaultPolicy(p =>
                {
                    p.SetIsOriginAllowed(o =>
                    {
                        var url = builder.Configuration["services:web:http:0"];
                        var allowedOrigins = new HashSet<string> { "http://localhost:3000" };

                        if (!string.IsNullOrEmpty(url))
                            allowedOrigins.Add(url);

                        return allowedOrigins.Contains(o);
                    });
                    p.AllowAnyHeader();
                    p.AllowAnyMethod();
                    p.AllowCredentials();
                }));

            return builder;
        }
    }

    extension(WebApplication app)
    {
        /// <summary>
        /// Configures the common middleware pipeline: OpenAPI (dev), CORS, exception
        /// handling, HTTPS redirection, authorization, controllers, and FastEndpoints.
        /// Call this after <c>app.MapDefaultEndpoints()</c>.
        /// </summary>
        public WebApplication UseApiDefaults()
        {
            if (app.Environment.IsDevelopment())
                app.MapOpenApi();

            app.UseCors();
            app.UseExceptionHandler(_ => { });
            app.UseHttpsRedirection();

            // Authentication is intentionally left out of the default pipeline since it requires additional configuration (e.g. JWT, cookies, etc.) that may not be relevant for all APIs
            // Re-enable this line if your API requires authentication and you've set up the necessary authentication services in AddApiDefaults or elsewhere
            // app.UseAuthentication();

            app.UseAuthorization();

            app.MapControllers();

            app.UseFastEndpoints(c =>
            {
                c.Serializer.Options.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
                c.Serializer.Options.PropertyNameCaseInsensitive = true;
                c.Endpoints.ShortNames = true;
            });

            return app;
        }
    }
}
