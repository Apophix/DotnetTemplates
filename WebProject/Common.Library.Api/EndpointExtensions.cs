using Microsoft.AspNetCore.Builder;
using Microsoft.OpenApi;

namespace Common.Library.Api;

public static class EndpointExtensions
{
    extension<TBuilder>(TBuilder builder) where TBuilder : IEndpointConventionBuilder
    {
        public TBuilder ProducesUnionResponse()
        {
            builder.AddOpenApiOperationTransformer((operation, context, ct) =>
            {
                operation.Extensions ??= new Dictionary<string, IOpenApiExtension>();
                operation.Extensions.Add("x-union-response", new JsonNodeExtension(true));
                return Task.CompletedTask;
            });

            return builder;
        }
    }
}
