var builder = DistributedApplication.CreateBuilder(args);

var api = builder.AddProject<Projects.WebProject_Api>("api");

builder.Build().Run();
