using Common.Library.Auth;
using Common.Library.DevSeeder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Sample.Infrastructure;
using WebProject.MigrationService;

var builder = Host.CreateApplicationBuilder(args);

builder.AddServiceDefaults();
builder.Services.AddHostedService<MigrationWorker>();

// add all infrastructure projects here
builder.Services.AddSampleInfrastructure((sp, o) =>
{
    var connStr = sp.GetRequiredService<IConfiguration>().GetConnectionString("app-db")
        ?? throw new InvalidOperationException("Connection string 'app-db' is not configured.");
    o.UseNpgsql(connStr);
});

// auth db context + Identity + OpenIddict core (server/validation live in the API only)
builder.Services.AddAuthCore((sp, o) =>
{
    var connStr = sp.GetRequiredService<IConfiguration>().GetConnectionString("app-db")
        ?? throw new InvalidOperationException("Connection string 'app-db' is not configured.");
    o.UseNpgsql(connStr);
});

// dev seeder — not registered in production
if (!builder.Environment.IsProduction())
    builder.Services.AddScoped<IdentityDevSeeder>();

var host = builder.Build();
host.Run();