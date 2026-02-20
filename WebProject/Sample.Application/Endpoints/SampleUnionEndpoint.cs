using System.Text.Json.Serialization;
using Common.Library.Api;
using FastEndpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

namespace Sample.Application.Endpoints;

public class SampleUnionEndpoint : Ep.NoReq.Res<SampleUnionResponse>
{
    public override void Configure()
    {
        // route should follow RESTful conventions, so it should be a noun or noun phrase that describes the resource being accessed, and it should be plural if it represents a collection of resources (singular for singleton resources)
        Get("/sample-union");
        AllowAnonymous();
        Description(b => b
                // naming endpoints is extremely important because the client generator uses the endpoint name to generate client method names, so you want to make sure it's a good name that clearly describes what the endpoint does
                // verbs are completely acceptable here, and often even preferred
            .WithName("getSampleUnionResponse")
                // at some point in the future I may add support to annotate the rest client with the summary and/or description
            .WithSummary("Returns a union response with either option 1 or option 2")
            .ProducesUnionResponse());
    }

    public override Task HandleAsync(CancellationToken ct)
    {
        var option1 = new SampleOption1 { Name = "John Doe" };
        var option2 = new SampleOption2 { Age = 30 };

        // For demonstration, we'll randomly return either option 1 or option 2
        var random = new Random();
        var response = random.Next(2) == 0 ? (SampleUnionResponse)option1 : (SampleUnionResponse)option2;

        return Send.OkAsync(response, cancellation: ct);
    }
}

// I prefer DTOs at the root of an endpoint contract to be named "Response" or "Request" to make it clear what they are used for
// Domain items that leave the application boundary, I prefer to be named "__Model" to make it clear they are domain items and not just used for a single endpoint

public class SampleUnionResponse
{
    private SampleUnionResponse()
    {
    }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public SampleOption1? Option1 { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public SampleOption2? Option2 { get; set; }

    public static implicit operator SampleUnionResponse(SampleOption1 option1) => new() { Option1 = option1 };
    public static implicit operator SampleUnionResponse(SampleOption2 option2) => new() { Option2 = option2 };
}

public class SampleOption1
{
    public required string Name { get; set; }
}

public class SampleOption2
{
    public required int Age { get; set; }
}