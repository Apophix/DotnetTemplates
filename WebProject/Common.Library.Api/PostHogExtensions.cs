using Microsoft.AspNetCore.Builder;
using PostHog;

namespace Common.Library.Api;

public static class PostHogExtensions
{
    extension(WebApplicationBuilder builder)
    {
        /// <summary>
        /// Registers PostHog if <c>PostHog:ProjectToken</c> is configured.
        /// Injects <see cref="PostHog.IPostHogClient"/> into the DI container for use
        /// in application services. When the token is absent this method is a no-op —
        /// inject <c>IPostHogClient?</c> (nullable) in application code to handle both cases.
        /// </summary>
        public WebApplicationBuilder AddPostHogDefaults()
        {
            if (!string.IsNullOrWhiteSpace(builder.Configuration["PostHog:ProjectToken"]))
                builder.AddPostHog();

            return builder;
        }
    }
}
