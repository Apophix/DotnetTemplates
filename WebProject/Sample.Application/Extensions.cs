using Microsoft.Extensions.DependencyInjection;

namespace Sample.Application;

public static class Extensions
{
    extension(IServiceCollection services)
    {
        public IServiceCollection AddSampleApplication()
        {
            return services;
        }
    }
}