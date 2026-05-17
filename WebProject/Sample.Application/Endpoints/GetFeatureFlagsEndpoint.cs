using FastEndpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.FeatureManagement;

namespace Sample.Application.Endpoints;

public class GetFeatureFlagsEndpoint : Ep.NoReq.Res<FeatureFlagsResponse>
{
    private readonly IFeatureManager _features;
    private readonly IConfiguration _config;

    public GetFeatureFlagsEndpoint(IFeatureManager features, IConfiguration config)
    {
        _features = features;
        _config = config;
    }

    public override void Configure()
    {
        Get("/feature-flags");
        AllowAnonymous();
        Description(b => b
            .WithName("getFeatureFlags")
            .WithSummary("Returns the current enabled state of all feature flags."));
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var names = _config.GetSection("FeatureManagement")
            .GetChildren()
            .Select(s => s.Key);

        var flags = new Dictionary<string, bool>();
        foreach (var name in names)
            flags[name] = await _features.IsEnabledAsync(name);

        await Send.OkAsync(new FeatureFlagsResponse { Flags = flags }, cancellation: ct);
    }
}

public class FeatureFlagsResponse
{
    public required Dictionary<string, bool> Flags { get; set; }
}
