using FastEndpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Sample.Application.Services;

namespace Sample.Application.Endpoints;

/// <summary>
/// Demonstrates the variant service pattern: the injected ICheckoutService is
/// transparently switched between LegacyCheckoutService and NewCheckoutService
/// based on the ExampleFlag feature flag — no flag logic in this endpoint.
/// </summary>
public class GetCheckoutVariantEndpoint : Ep.NoReq.Res<CheckoutVariantResponse>
{
    private readonly ICheckoutService _checkout;

    public GetCheckoutVariantEndpoint(ICheckoutService checkout)
    {
        _checkout = checkout;
    }

    public override void Configure()
    {
        Get("/checkout-variant");
        AllowAnonymous();
        Description(b => b
            .WithName("getCheckoutVariant")
            .WithSummary("Returns which checkout service variant is active based on the ExampleFlag feature flag."));
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var summary = await _checkout.GetSummaryAsync(ct);
        await Send.OkAsync(new CheckoutVariantResponse
        {
            Variant = summary.Variant,
            Description = summary.Description,
            Total = summary.Total,
        }, cancellation: ct);
    }
}

public class CheckoutVariantResponse
{
    public required string Variant { get; set; }
    public required string Description { get; set; }
    public required decimal Total { get; set; }
}
