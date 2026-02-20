using Microsoft.EntityFrameworkCore;
using Sample.Domain.Entities;

namespace Sample.Tests.Integration;

[Collection(DatabaseCollection.Name)]
public class SampleItemRepositoryTests(DatabaseFixture db)
{
    [Fact]
    public async Task CanInsertAndRetrieve_SampleItem()
    {
        var item = new SampleItem
        {
            Id = Guid.NewGuid(),
            Name = "Integration test item",
            CreatedAt = DateTime.UtcNow,
        };

        await using var ctx = db.CreateDbContext();
        ctx.SampleItems.Add(item);
        await ctx.SaveChangesAsync();

        await using var readCtx = db.CreateDbContext();
        var retrieved = await readCtx.SampleItems.FirstOrDefaultAsync(x => x.Id == item.Id);

        // Shouldly: fluent guard assertion
        retrieved.ShouldNotBeNull();
        retrieved.Name.ShouldBe(item.Name);

        // Verify: snapshot the full shape of the returned object.
        // On first run this creates a .verified file for you to approve;
        // subsequent runs compare against it.
        await Verify(retrieved)
            .ScrubMember<SampleItem>(x => x.Id)
            .ScrubMember<SampleItem>(x => x.CreatedAt);
    }
}
