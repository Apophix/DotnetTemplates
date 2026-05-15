using Common.Library.Api;
using Common.Library.Auth;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.FeatureManagement;
using Sample.Application;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddApiDefaults();
builder.Services.AddFeatureManagement();
builder.AddPostHogDefaults();

builder.Services.AddSampleApplication((sp, o) =>
{
    var connStr = sp.GetRequiredService<IConfiguration>().GetConnectionString("app-db")
        ?? throw new InvalidOperationException("Connection string 'app-db' is not configured.");
    o.UseNpgsql(connStr);
});

builder.AddAuthDefaults((sp, o) =>
{
    var connStr = sp.GetRequiredService<IConfiguration>().GetConnectionString("app-db")
        ?? throw new InvalidOperationException("Connection string 'app-db' is not configured.");
    o.UseNpgsql(connStr);
});

var app = builder.Build();

app.MapDefaultEndpoints();
app.UseApiDefaults();

app.Run();