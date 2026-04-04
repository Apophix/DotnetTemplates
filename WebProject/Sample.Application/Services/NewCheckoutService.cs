namespace Sample.Application.Services;

/// <summary>
/// The redesigned checkout flow. Active when the ExampleFlag feature flag is enabled.
/// </summary>
public class NewCheckoutService : ICheckoutService
{
    public string Variant => "new-checkout";

    public Task<CheckoutSummary> GetSummaryAsync(CancellationToken ct = default) =>
        Task.FromResult(new CheckoutSummary(
            Variant: Variant,
            Description: "Streamlined multi-step checkout with express options",
            Total: 99.99m));
}
