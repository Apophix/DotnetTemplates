using Common.Library.Auth;
using Microsoft.AspNetCore.Identity;
using OpenIddict.Abstractions;

namespace Common.Library.DevSeeder;

/// <summary>
/// Seeds dev-only data: Identity roles, dev user accounts, and the OpenIddict SPA
/// application registration. Only registered in DI for non-production environments.
/// </summary>
public class IdentityDevSeeder(
    UserManager<AppUser> userManager,
    RoleManager<AppRole> roleManager,
    IOpenIddictApplicationManager applicationManager) : IDevDataSeeder
{
    private const string DevPassword = "DevPass1!";

    public async Task SeedTestDataAsync(CancellationToken cancellationToken = default)
    {
        await SeedRolesAsync();
        await SeedUsersAsync();
        await SeedOpenIddictApplicationAsync(cancellationToken);
    }

    private async Task SeedRolesAsync()
    {
        foreach (var role in new[] { "User", "Admin" })
        {
            if (!await roleManager.RoleExistsAsync(role))
                await roleManager.CreateAsync(new AppRole { Name = role });
        }
    }

    private async Task SeedUsersAsync()
    {
        await EnsureUserAsync("dev-user-001", "user@localhost", ["User"]);
        await EnsureUserAsync("dev-admin-001", "admin@localhost", ["User", "Admin"]);
    }

    private async Task EnsureUserAsync(string id, string email, string[] roles)
    {
        if (await userManager.FindByEmailAsync(email) is not null)
            return;

        var user = new AppUser
        {
            Id = id,
            UserName = email,
            Email = email,
            EmailConfirmed = true,
        };

        var result = await userManager.CreateAsync(user, DevPassword);
        if (!result.Succeeded)
            throw new InvalidOperationException(
                $"Failed to seed dev user '{email}': {string.Join(", ", result.Errors.Select(e => e.Description))}");

        await userManager.AddToRolesAsync(user, roles);
    }

    private async Task SeedOpenIddictApplicationAsync(CancellationToken cancellationToken)
    {
        const string clientId = "web-client";

        if (await applicationManager.FindByClientIdAsync(clientId, cancellationToken) is not null)
            return;

        await applicationManager.CreateAsync(new OpenIddictApplicationDescriptor
        {
            ClientId = clientId,
            DisplayName = "WebProject Web Client",
            ClientType = OpenIddictConstants.ClientTypes.Public,
            ConsentType = OpenIddictConstants.ConsentTypes.Implicit,
            Permissions =
            {
                OpenIddictConstants.Permissions.Endpoints.Authorization,
                OpenIddictConstants.Permissions.Endpoints.Token,
                OpenIddictConstants.Permissions.Endpoints.EndSession,
                OpenIddictConstants.Permissions.GrantTypes.AuthorizationCode,
                OpenIddictConstants.Permissions.GrantTypes.Password,
                OpenIddictConstants.Permissions.GrantTypes.RefreshToken,
                OpenIddictConstants.Permissions.ResponseTypes.Code,
                OpenIddictConstants.Permissions.Scopes.Email,
                OpenIddictConstants.Permissions.Scopes.Profile,
                OpenIddictConstants.Permissions.Scopes.Roles,
                OpenIddictConstants.Permissions.Prefixes.Scope + OpenIddictConstants.Scopes.OfflineAccess,
            },
            // Dev redirect URIs — Vite default port. Update if your local port differs.
            RedirectUris = { new Uri("http://localhost:5173/auth/callback") },
            PostLogoutRedirectUris = { new Uri("http://localhost:5173") },
        }, cancellationToken);
    }
}
