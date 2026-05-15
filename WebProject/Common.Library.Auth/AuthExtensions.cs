using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Common.Library.Auth;

public static class AuthExtensions
{
    extension(IServiceCollection services)
    {
        /// <summary>
        /// Registers AppDbContext, ASP.NET Core Identity, and OpenIddict Core.
        /// Used by both <c>AddAuthDefaults</c> (API) and the MigrationService/seeder.
        /// </summary>
        /// <param name="configureDatabase">
        /// Configures the database provider and connection string.
        /// Example: <c>(sp, o) => o.UseNpgsql(connStr)</c>
        /// </param>
        public IServiceCollection AddAuthCore(Action<IServiceProvider, DbContextOptionsBuilder> configureDatabase)
        {
            services.AddDbContext<AppDbContext>((sp, o) =>
            {
                configureDatabase(sp, o);
                o.UseOpenIddict();
            });

            services.AddIdentity<AppUser, AppRole>(o =>
                {
                    o.Password.RequireDigit = true;
                    o.Password.RequiredLength = 8;
                    o.Password.RequireNonAlphanumeric = true;
                    o.Password.RequireUppercase = true;
                    o.Password.RequireLowercase = true;
                    o.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
                    o.Lockout.MaxFailedAccessAttempts = 5;
                    o.User.RequireUniqueEmail = true;
                })
                .AddEntityFrameworkStores<AppDbContext>()
                .AddDefaultTokenProviders();

            services.AddOpenIddict()
                .AddCore(o =>
                {
                    o.UseEntityFrameworkCore()
                     .UseDbContext<AppDbContext>();
                });

            return services;
        }
    }

    extension(WebApplicationBuilder builder)
    {
        /// <summary>
        /// Registers Identity, AppDbContext, and OpenIddict (core + server + validation).
        /// Call this after <c>builder.AddApiDefaults()</c>.
        /// </summary>
        /// <param name="configureDatabase">
        /// Configures the database provider and connection string.
        /// Example: <c>(sp, o) => o.UseNpgsql(connStr)</c>
        /// </param>
        public WebApplicationBuilder AddAuthDefaults(Action<IServiceProvider, DbContextOptionsBuilder> configureDatabase)
        {
            builder.Services.AddAuthCore(configureDatabase);

            // Server and validation are API-specific — not registered in MigrationService.
            builder.Services.AddOpenIddict()
                .AddServer(o =>
                {
                    o.SetTokenEndpointUris("/connect/token")
                     .SetAuthorizationEndpointUris("/connect/authorize")
                     .SetUserInfoEndpointUris("/connect/userinfo")
                     .SetEndSessionEndpointUris("/connect/logout");

                    o.AllowAuthorizationCodeFlow()
                     .RequireProofKeyForCodeExchange();

                    o.AllowRefreshTokenFlow();

                    // Resource owner password grant — enabled only in non-production
                    // via Authentication:AllowPasswordGrant: true (set in appsettings.local.json).
                    // Never set this in production.
                    if (builder.Configuration.GetValue<bool>("Authentication:AllowPasswordGrant")
                        && !builder.Environment.IsProduction())
                    {
                        o.AllowPasswordFlow();
                    }

                    o.AddDevelopmentEncryptionCertificate()
                     .AddDevelopmentSigningCertificate();

                    o.UseAspNetCore()
                     .EnableTokenEndpointPassthrough()
                     .EnableAuthorizationEndpointPassthrough()
                     .EnableUserInfoEndpointPassthrough()
                     .EnableEndSessionEndpointPassthrough();
                })
                .AddValidation(o =>
                {
                    o.UseLocalServer();
                    o.UseAspNetCore();
                });

            return builder;
        }
    }

    extension(WebApplication app)
    {
        /// <summary>
        /// Enables authentication and authorization middleware.
        /// Call this inside <c>UseApiDefaults()</c> or after it in the pipeline.
        /// </summary>
        public WebApplication UseAuthDefaults()
        {
            app.UseAuthentication();
            app.UseAuthorization();

            return app;
        }
    }
}
