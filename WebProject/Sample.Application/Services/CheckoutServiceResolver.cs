using Microsoft.Extensions.DependencyInjection;
using Microsoft.FeatureManagement;

namespace Sample.Application.Services;

/// <summary>
/// Variant resolver for ICheckoutService.
/// Registered as the default ICheckoutService; selects the keyed implementation
/// at request time based on the ExampleFlag feature flag.
///
/// Pattern: register multiple keyed implementations, resolve the right one via
/// a thin proxy that consults IFeatureManager. Callers inject ICheckoutService
/// as normal — they never see the switching logic.
/// </summary>
public class CheckoutServiceResolver : ICheckoutService
{
    private readonly IFeatureManager _features;
    private readonly ICheckoutService _legacy;
    private readonly ICheckoutService _new;

    public CheckoutServiceResolver(
        IFeatureManager features,
        [FromKeyedServices(CheckoutVariant.Legacy)] ICheckoutService legacy,
        [FromKeyedServices(CheckoutVariant.New)] ICheckoutService @new)
    {
        _features = features;
        _legacy = legacy;
        _new = @new;
    }

    // Delegates Variant to whichever implementation is active.
    public string Variant => _legacy.Variant; // resolved lazily per-call below

    public async Task<CheckoutSummary> GetSummaryAsync(CancellationToken ct = default)
    {
        var service = await _features.IsEnabledAsync(FeatureFlags.ExampleFlag) ? _new : _legacy;
        return await service.GetSummaryAsync(ct);
    }
}

/// <summary>Keys used for keyed service registration.</summary>
public static class CheckoutVariant
{
    public const string Legacy = "legacy";
    public const string New = "new-checkout";
}
