using Common.Library.DevSeeder;
using Microsoft.EntityFrameworkCore;

namespace WebProject.MigrationService;

public partial class MigrationWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IHostApplicationLifetime _applicationLifetime;
    private readonly ILogger<MigrationWorker> _logger;

    public MigrationWorker(IServiceProvider serviceProvider, IHostApplicationLifetime applicationLifetime,
        ILogger<MigrationWorker> logger)
    {
        _serviceProvider = serviceProvider;
        _applicationLifetime = applicationLifetime;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var scope = _serviceProvider.CreateScope();

        var dbContexttypes = AppDomain.CurrentDomain.GetAssemblies()
            .SelectMany(assembly => assembly.GetTypes())
            .Where(type => type is { IsClass: true, IsAbstract: false } && type.IsSubclassOf(typeof(DbContext)));

        foreach (var contextType in dbContexttypes)
        {
            if (scope.ServiceProvider.GetService(contextType) is not DbContext dbContext)
            {
                LogCouldNotResolveDbcontextOfTypeDbcontexttype(contextType.FullName ?? "Unknown Context Type");
                continue;
            }

            await dbContext.Database.MigrateAsync(stoppingToken);
        }

        // dev seeding data
        var seederTypes = AppDomain.CurrentDomain.GetAssemblies()
            .SelectMany(assembly => assembly.GetTypes())
            .Where(type => type.GetInterfaces().Any(i => i == typeof(IDevDataSeeder)));

        foreach (var seederType in seederTypes)
        {
            if (scope.ServiceProvider.GetService(seederType) is not IDevDataSeeder seeder)
            {
                _logger.LogWarning("Could not resolve Data Seeder of type {SeederType}",
                    seederType.FullName ?? "Unknown Seeder Type");
                continue;
            }
            await seeder.SeedTestDataAsync(stoppingToken);
        }

        // shut down the application once migrations are complete
        _applicationLifetime.StopApplication();
    }

    [LoggerMessage(LogLevel.Warning, "Could not resolve DbContext of type {DbContextType}")]
    partial void LogCouldNotResolveDbcontextOfTypeDbcontexttype(string DbContextType);
}