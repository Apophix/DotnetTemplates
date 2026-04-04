namespace Sample.Application.Services;

public interface ICheckoutService
{
    /// <summary>Returns which implementation variant is active.</summary>
    string Variant { get; }

    Task<CheckoutSummary> GetSummaryAsync(CancellationToken ct = default);
}

public record CheckoutSummary(string Variant, string Description, decimal Total);
