using Sample.Infrastructure;
using WebProject.MigrationService;

var builder = Host.CreateApplicationBuilder(args);

builder.AddServiceDefaults();
builder.Services.AddHostedService<MigrationWorker>();

// add all infrastructure projects here
builder.Services.AddSampleInfrastructure();

var host = builder.Build();
host.Run();