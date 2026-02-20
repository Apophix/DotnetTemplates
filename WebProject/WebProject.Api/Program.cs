using System.Text.Json;
using System.Text.Json.Serialization;
using Common.Library.Logging;
using FastEndpoints;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.OpenApi;
using Sample.Application;

var builder = WebApplication.CreateBuilder(args);

// Aspire defaults
builder.AddServiceDefaults();

// Serilog
builder.AddSerilogLogging();

// enums work better this way
builder.Services.Configure<JsonOptions>(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    o.SerializerOptions.PropertyNameCaseInsensitive = true;
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
});

// can use controllers or FastEndpoints, or both together
builder.Services.AddControllers();
builder.Services.AddFastEndpoints();
builder.Services.AddOpenApi(o => o.OpenApiVersion = OpenApiSpecVersion.OpenApi3_0);

// use ProblemDetails for error handling
builder.Services.AddProblemDetails();

// configure CORS to allow the frontend to call the API - this is a basic implementation, you may want to make it more robust for production use
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

// register domain modules
builder.Services.AddSampleApplication();

var app = builder.Build();

// aspire defaults
app.MapDefaultEndpoints();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();
app.UseExceptionHandler();
app.UseHttpsRedirection();

app.UseAuthorization();

// commented by default - re-enable if you have authentication configured and want to use the [Authorize] attribute in your endpoints
// app.UseAuthentication();

app.MapControllers();

// make sure to configure these options for FastEndpoints to ensure consistent serialization settings and to enable short names for endpoints in the OpenAPI spec
app.UseFastEndpoints(c =>
{
    c.Serializer.Options.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    c.Serializer.Options.PropertyNameCaseInsensitive = true;
    c.Endpoints.ShortNames = true;
});

app.Run();