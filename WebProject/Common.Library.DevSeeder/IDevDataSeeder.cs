namespace Common.Library.DevSeeder;

public interface IDevDataSeeder
{
    Task SeedTestDataAsync(CancellationToken cancellationToken = default);
}
