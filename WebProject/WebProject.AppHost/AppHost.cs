var builder = DistributedApplication.CreateBuilder(args);


// Only host Seq if a local instance isn't already running on the default port
const int seqDefaultPort = 5341;
var seqIsAlreadyRunning = IsPortInUse(seqDefaultPort);
var seq = seqIsAlreadyRunning
    ? null
    : builder.AddSeq("seq")
             .WithLifetime(ContainerLifetime.Persistent);

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

if (seq is not null)
    api.WithReference(seq).WaitFor(seq);

api.WithReference(database).WaitFor(database);

var web = builder.AddViteApp("web", "../WebProject.Web")
    .WithEndpoint("http", e => e.Port = 5173)
    .WithEnvironment("VITE_API_URL", api.GetEndpoint("https"))
    .WithReference(api);

api.WithReference(web);

builder.Build().Run();

static bool IsPortInUse(int port)
{
    try
    {
        using var client = new System.Net.Sockets.TcpClient();
        client.Connect("127.0.0.1", port);
        return true;
    }
    catch
    {
        return false;
    }
}
