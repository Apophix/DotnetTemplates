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
        /// Writes to console and, when a "seq" connection string is present, to a Seq instance.
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

                var seqUrl = context.Configuration.GetConnectionString("seq");
                if (!string.IsNullOrWhiteSpace(seqUrl))
                    config.WriteTo.Seq(seqUrl);
            });

            return builder;
        }
    }
}
