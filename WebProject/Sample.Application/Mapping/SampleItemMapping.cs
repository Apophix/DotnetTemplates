using Mapster;
using Sample.Domain.Entities;
using Sample.Public.Objects;

namespace Sample.Application.Mapping;

// this is one way to do this
// you could also use DI injected mapper classes, or whatever you want really

// I'm using Mapster here,
// you could of course also do manual mapping
// and in the case of simple mappings, you could just literally call .Adapt<T>() directly in the code where you need it without any extension methods at all
// my current preference is to have the mapping code in extension methods, even if they are just one-liners, because it keeps the mapping code in one place and makes it easy to find and change if needed

public static class SampleItemMapping
{
    extension(SampleItem item)
    {
        public SampleItemDto ToDto() => item.Adapt<SampleItemDto>();
    }

    extension(SampleItemDto dto)
    {
        public SampleItem ToEntity() => dto.Adapt<SampleItem>();
    }
}