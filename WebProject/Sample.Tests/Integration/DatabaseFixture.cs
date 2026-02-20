using DotNet.Testcontainers.Builders;
using Microsoft.EntityFrameworkCore;
using Sample.Infrastructure.Persistence;
using Testcontainers.PostgreSql;

namespace Sample.Tests.Integration;

/// <summary>
/// Spins up a real PostgreSQL container once per test collection and provides a
/// freshly-migrated <see cref="SampleDbContext"/> to each test.
/// </summary>
public sealed class DatabaseFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .WithCleanUp(true)
        .Build();

    public SampleDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<SampleDbContext>()
            .UseNpgsql(_container.GetConnectionString())
            .Options;

        return new SampleDbContext(options);
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();

        // Apply migrations / create schema
        await using var ctx = CreateDbContext();
        await ctx.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
    }
}

[CollectionDefinition(Name)]
public sealed class DatabaseCollection : ICollectionFixture<DatabaseFixture>
{
    public const string Name = "Database";
}
