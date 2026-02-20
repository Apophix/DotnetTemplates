using Sample.Domain.Entities;

namespace Sample.Tests.Unit;

public class SampleItemTests
{
    [Fact]
    public void SampleItem_WithValidData_SetsPropertiesCorrectly()
    {
        var id = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var item = new SampleItem
        {
            Id = id,
            Name = "Test item",
            CreatedAt = now,
        };

        item.Id.ShouldBe(id);
        item.Name.ShouldBe("Test item");
        item.CreatedAt.ShouldBe(now);
    }
}
