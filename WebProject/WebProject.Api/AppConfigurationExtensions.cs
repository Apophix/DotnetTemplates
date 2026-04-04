using Azure.Identity;
using Microsoft.Extensions.Configuration.AzureAppConfiguration;
using Microsoft.FeatureManagement;

namespace WebProject.Api;

public static class AppConfigurationExtensions
{
    extension(WebApplicationBuilder builder)
    {
        public WebApplicationBuilder AddAzureAppConfigurationDefaults()
        {
            var endpoint = builder.Configuration["AppConfiguration:Endpoint"];
            if (!string.IsNullOrEmpty(endpoint))
            {
                var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                {
                    ManagedIdentityClientId = builder.Configuration["AZURE_CLIENT_ID"],
                });
                var environment = builder.Environment.EnvironmentName.ToLowerInvariant();
                var slotLabel = builder.Configuration["SLOT_NAME"];

                builder.Configuration.AddAzureAppConfiguration(options =>
                    options.Connect(new Uri(endpoint), credential)
                           .Select(KeyFilter.Any, LabelFilter.Null)       // shared keys (no label)
                           .Select(KeyFilter.Any, environment)             // environment overrides (e.g. "staging", "production")
                           .Select(KeyFilter.Any,
                               string.IsNullOrEmpty(slotLabel) ? LabelFilter.Null : slotLabel) // PR slot overrides
                           .UseFeatureFlags()
                           .ConfigureKeyVault(kv => kv.SetCredential(credential))
                           .ConfigureRefresh(refresh => refresh
                               .Register("Sentinel", refreshAll: true)));

                builder.Services.AddAzureAppConfiguration();
            }

            // Always register so IFeatureManager is available everywhere,
            // including local dev where flags are read from appsettings.
            builder.Services.AddFeatureManagement();

            return builder;
        }
    }

    extension(WebApplication app)
    {
        public WebApplication UseAzureAppConfigurationDefaults()
        {
            // Only activate the refresh middleware when Azure App Configuration is wired up.
            // IConfigurationRefresherProvider is registered by AddAzureAppConfiguration().
            if (app.Services.GetService<IConfigurationRefresherProvider>() is not null)
                app.UseAzureAppConfiguration();

            return app;
        }
    }
}
