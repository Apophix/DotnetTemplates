using Microsoft.Extensions.DependencyInjection;
using Sample.Infrastructure;

namespace Sample.Application;

public static class Extensions
{
    extension(IServiceCollection services)
    {
        public IServiceCollection AddSampleApplication()
        {
            services.AddSampleInfrastructure();
            return services;
        }
    }
}