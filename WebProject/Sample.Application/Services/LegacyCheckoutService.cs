namespace Sample.Application.Services;

/// <summary>
/// The original checkout flow. Active when the ExampleFlag feature flag is disabled.
/// </summary>
public class LegacyCheckoutService : ICheckoutService
{
    public string Variant => "legacy";

    public Task<CheckoutSummary> GetSummaryAsync(CancellationToken ct = default) =>
        Task.FromResult(new CheckoutSummary(
            Variant: Variant,
            Description: "Classic single-page checkout",
            Total: 99.99m));
}
