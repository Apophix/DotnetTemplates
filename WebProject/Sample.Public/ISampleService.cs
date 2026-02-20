using Sample.Public.Objects;

namespace Sample.Public;

// if the class is serving as a pure reader service, "Provider" is a good naming convention
public interface ISampleService
{
    public Task<SampleItemDto> GetSampleItemAsync(Guid id, CancellationToken cancellationToken = default);
}
