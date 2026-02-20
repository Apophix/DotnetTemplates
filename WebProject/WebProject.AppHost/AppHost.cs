var builder = DistributedApplication.CreateBuilder(args);

// Only host Seq if a local instance isn't already running on the default port
const int seqDefaultPort = 5341;
var seqIsAlreadyRunning = IsPortInUse(seqDefaultPort);
var seq = seqIsAlreadyRunning
    ? null
    : builder.AddSeq("seq");

var api = builder.AddProject<Projects.WebProject_Api>("api");

if (seq is not null)
    api.WithReference(seq).WaitFor(seq);

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
