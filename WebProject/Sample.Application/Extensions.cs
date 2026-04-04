using Microsoft.Extensions.DependencyInjection;
using Sample.Application.Services;
using Sample.Infrastructure;

namespace Sample.Application;

public static class Extensions
{
    extension(IServiceCollection services)
    {
        public IServiceCollection AddSampleApplication()
        {
            services.AddSampleInfrastructure();

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