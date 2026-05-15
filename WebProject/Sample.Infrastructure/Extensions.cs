using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Sample.Infrastructure.Persistence;

namespace Sample.Infrastructure;

public static class Extensions
{
    extension(IServiceCollection services)
    {
        /// <param name="configureDatabase">
        /// Configures the database provider and connection string.
        /// Example: <c>(sp, o) => o.UseNpgsql(sp.GetRequiredService&lt;IConfiguration&gt;().GetConnectionString("app-db"))</c>
        /// </param>
        public IServiceCollection AddSampleInfrastructure(Action<IServiceProvider, DbContextOptionsBuilder> configureDatabase)
        {
            services.AddDbContext<SampleDbContext>(configureDatabase);
            services.AddDbContextFactory<SampleDbContext>(configureDatabase, ServiceLifetime.Scoped);

            return services;
        }
    }
}
