using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Common.Library.Api;

/// <summary>
/// Development-only middleware: injects a configured persona as the authenticated identity.
/// Select a persona per-request via the X-Dev-Persona header (defaults to Authentication:DevBypass:DefaultPersona).
/// Each persona has its own sub/name/email/roles, making it easy to test role-based access.
/// Replace with real Entra External ID JWT bearer auth when ready.
/// </summary>
public class DevAuthMiddleware(IConfiguration config, IHostEnvironment env, RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (env.IsDevelopment()
            && config.GetValue<bool>("Authentication:DevBypass:Enabled")
            && context.User.Identity?.IsAuthenticated != true)
        {
            var personaName = context.Request.Headers["X-Dev-Persona"].FirstOrDefault()
                ?? config["Authentication:DevBypass:DefaultPersona"]
                ?? "default";

            var section = config.GetSection($"Authentication:DevBypass:Personas:{personaName}");
            if (!section.Exists())
                section = config.GetSection("Authentication:DevBypass:Personas:default");

            var sub   = section["Sub"]   ?? "dev-user";
            var name  = section["Name"]  ?? "Dev User";
            var email = section["Email"] ?? "dev@localhost";
            var roles = section.GetSection("Roles").Get<string[]>() ?? [];

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, sub),
                new(ClaimTypes.Name, name),
                new(ClaimTypes.Email, email),
            };
            foreach (var role in roles)
                claims.Add(new Claim(ClaimTypes.Role, role));

            context.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "DevBypass"));
        }

        await next(context);
    }
}
