var builder = DistributedApplication.CreateBuilder(args);

builder.AddProject<Projects.WebProject_Api>("webproject-api");

builder.Build().Run();
