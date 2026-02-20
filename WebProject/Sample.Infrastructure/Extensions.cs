using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Sample.Infrastructure.Persistence;

namespace Sample.Infrastructure;

public static class Extensions
{
    extension(IServiceCollection services)
    {
        public IServiceCollection AddSampleInfrastructure()
        {
            services.AddDbContext<SampleDbContext>((sp, options) =>
                options.UseNpgsql(GetConnectionString(sp)));

            services.AddDbContextFactory<SampleDbContext>((sp, options) =>
                options.UseNpgsql(GetConnectionString(sp)), ServiceLifetime.Scoped);

            return services;
        }
    }

    private static string GetConnectionString(IServiceProvider sp) =>
        sp.GetRequiredService<IConfiguration>().GetConnectionString("app-db")
        ?? throw new InvalidOperationException("Connection string 'app-db' is not configured.");
}
