using Common.Library.Api;
using Sample.Application;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddApiDefaults();

// register domain modules
builder.Services.AddSampleApplication();

var app = builder.Build();

app.MapDefaultEndpoints();
app.UseApiDefaults();

app.Run();