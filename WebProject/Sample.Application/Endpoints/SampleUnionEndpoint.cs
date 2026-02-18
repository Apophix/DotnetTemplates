using System.Text.Json.Serialization;
using Common.Library.Endpoints;
using FastEndpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

namespace Sample.Application.Endpoints;

public class SampleUnionEndpoint : Ep.NoReq.Res<SampleUnionResponse>
{
    public override void Configure()
    {
        Get("/sample-union");
        AllowAnonymous();
        Description(b => b
            .WithName("getSampleUnionResponse")
            .WithSummary("Returns a union response with either option 1 or option 2")
            .ProducesUnionResponse());
    }
}

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