using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Sample.Application.Services;
using Sample.Infrastructure;

namespace Sample.Application;

public static class Extensions
{
    extension(IServiceCollection services)
    {
        /// <param name="configureDatabase">
        /// Configures the database provider and connection string, forwarded to infrastructure.
        /// Example: <c>(sp, o) => o.UseNpgsql(connStr)</c>
        /// </param>
        public IServiceCollection AddSampleApplication(Action<IServiceProvider, DbContextOptionsBuilder> configureDatabase)
        {
            services.AddSampleInfrastructure(configureDatabase);

            // Variant service pattern: two keyed implementations + a resolver proxy.
            // Callers inject ICheckoutService normally; the resolver picks the active
            // variant at request time via IFeatureManager (ExampleFlag flag).
            services.AddKeyedScoped<ICheckoutService, LegacyCheckoutService>(CheckoutVariant.Legacy);
            services.AddKeyedScoped<ICheckoutService, NewCheckoutService>(CheckoutVariant.New);
            services.AddScoped<ICheckoutService, CheckoutServiceResolver>();

            return services;
        }
    }
}