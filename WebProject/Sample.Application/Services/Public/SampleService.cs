using Sample.Application.Mapping;
using Sample.Domain.Entities;
using Sample.Public;
using Sample.Public.Objects;

namespace Sample.Application.Services.Public;

public class SampleService : ISampleService
{
    public async Task<SampleItemDto> GetSampleItemAsync(Guid id, CancellationToken cancellationToken = default)
    {
        // In a real application, you would typically retrieve the item from a database or another data source.
        var someDomainItem = new SampleItem
        {
            Id = id,
            Name = "Test item",
            CreatedAt = DateTime.UtcNow,
        };

        // modules communicate via dedicated DTOs, so we convert the domain entity to a DTO before returning it.
        return someDomainItem.ToDto();
    }
}