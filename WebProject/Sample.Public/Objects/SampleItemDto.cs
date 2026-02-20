namespace Sample.Public.Objects;

// I'm not too fussed about the directory naming for this,
// it can be "Objects", "Dtos", whatever

// I am not sure I like the "Dto" suffix here, I'd almost rather have something more specific that indicates it's specifically a "Module Communication Object",
// but I don't have a better name for that. "Mto (Module Transfer Object)"?
// in my head, "Dto" is a last resort if there isn't a more specific naming convention that makes sense

// there is also an argument to be made that this should just be "SampleItem" to keep the public api clean,
// and the domain item should be identified as "SampleItemEntity", or some other suffix to indicate it's a domain entity
public class SampleItemDto
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public DateTime CreatedAt { get; set; }
}