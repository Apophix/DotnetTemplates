var builder = DistributedApplication.CreateBuilder(args);

var api = builder.AddProject<Projects.WebProject_Api>("api");

var web = builder.AddViteApp("web", "../WebProject.Web")
    .WithEnvironment("VITE_API_URL", api.GetEndpoint("https"))
    .WithReference(api);

api.WithReference(web);

builder.Build().Run();
