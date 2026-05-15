using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Serilog;

namespace Common.Library.Logging;

public static class LoggingExtensions
{
    extension(WebApplicationBuilder builder)
    {
        /// <summary>
        /// Configures Serilog as the logging provider.
        /// Reads base configuration from appsettings (Serilog section).
        /// Writes to console.
        /// </summary>
        public WebApplicationBuilder AddSerilogLogging()
        {
            builder.Host.UseSerilog((context, services, config) =>
            {
                config
                    .ReadFrom.Configuration(context.Configuration)
                    .ReadFrom.Services(services)
                    .Enrich.FromLogContext()
                    .WriteTo.Console(
                        outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext}: {Message:lj}{NewLine}{Exception}"
                    );
            });

            return builder;
        }
    }
}
