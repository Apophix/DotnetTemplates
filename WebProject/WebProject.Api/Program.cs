using Common.Library.Api;
using Sample.Application;
using WebProject.Api;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddApiDefaults();
builder.AddAzureAppConfigurationDefaults();

builder.Services.AddSampleApplication();

var app = builder.Build();

app.MapDefaultEndpoints();
app.UseAzureAppConfigurationDefaults();
app.UseApiDefaults();

app.Run();