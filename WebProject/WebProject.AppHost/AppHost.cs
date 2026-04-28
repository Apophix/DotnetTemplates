var builder = DistributedApplication.CreateBuilder(args);

// ── Database ──────────────────────────────────────────────────────────────
// Default: PostgreSQL.
// To switch to SQL Server: comment the Postgres lines, uncomment SqlServer.
// The connection string name ("app-db") stays the same either way.
var database = builder.AddPostgres("postgres")
                      .WithLifetime(ContainerLifetime.Persistent)
                      .WithDataVolume()
                      .AddDatabase("app-db");

// var database = builder.AddSqlServer("sqlserver")
//                       .WithLifetime(ContainerLifetime.Persistent)
//                       .WithDataVolume()
//                       .AddDatabase("app-db");

var api = builder.AddProject<Projects.WebProject_Api>("api")
    .WaitFor(database)
    .WithReference(database);

builder.AddProject<Projects.WebProject_MigrationService>("webproject-migrationservice")
    .WaitFor(database)
    .WithReference(database);

var web = builder.AddViteApp("web", "../WebProject.Web")
    .WithEndpoint("http", e => e.Port = 5173)
    .WithEnvironment("VITE_API_BASE_URL", api.GetEndpoint("https"))
    .WithReference(api);

api.WithReference(web);

builder.Build().Run();
