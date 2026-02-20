namespace Sample.Domain.Entities;

public class SampleItem
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public DateTime CreatedAt { get; set; }
}
