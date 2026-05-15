using Common.Library.Auth;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace WebProject.MigrationService;

/// <summary>
/// Provides a design-time AppDbContext for EF Core tooling (dotnet ef migrations).
/// Lives here — not in Common.Library.Auth — so the library stays provider-agnostic.
/// Swap UseNpgsql for UseSqlServer here if migrating to SQL Server.
/// </summary>
public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql("Host=localhost;Database=design-time;Username=design-time")
            .UseOpenIddict()
            .Options;

        return new AppDbContext(options);
    }
}
