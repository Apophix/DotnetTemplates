using Common.Library.Api;
using Microsoft.FeatureManagement;
using Sample.Application;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddApiDefaults();
builder.Services.AddFeatureManagement();
builder.AddPostHogDefaults();

builder.Services.AddSampleApplication();

var app = builder.Build();

app.MapDefaultEndpoints();
app.UseApiDefaults();

app.Run();