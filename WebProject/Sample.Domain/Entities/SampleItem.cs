using Mapster;
using Sample.Public.Objects;

namespace Sample.Domain.Entities;

public class SampleItem
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public DateTime CreatedAt { get; set; }

    public SampleItemDto ToDto()
    {
        // I'm using Mapster here
        // you can also just return a new SampleItemDto and map the properties manually.
        return this.Adapt<SampleItemDto>();
    }

    public static SampleItem FromDto(SampleItemDto dto)
    {
        return dto.Adapt<SampleItem>();
    }
}

// Note: there is a valid argument to be made that you should have the mapping code in a separate extension method or even a separate mapper class
// I haven't quite decided on the approach I like best
