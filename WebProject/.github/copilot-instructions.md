# GitHub Copilot Instructions

## Project Context
You're working on this web project, which is a modern full-stack application template designed for rapid development and scalability.

## Key Technologies
- **Backend**: .NET 10+ with FastEndpoints, Entity Framework Core, Aspire
- **Frontend**: React 19, TypeScript, Vite, TanStack Start/Router/Query, Tailwind CSS v4
  - **Important**: Tanstack Start is set to SPA mode

## Critical Rules

### DO
✅ Use TypeScript strict mode - always type everything  
✅ Use functional React components with hooks  
✅ Prefer named functions (`function name() {}`) over const arrow functions (`const name = () => {}`)  
✅ Exception: Use arrow functions for lambdas (e.g., `.map(item => ...)`)  
✅ Prefer Shadcn components when available for UI elements  
✅ Prefer TanStack Form over manual form handling for complex forms  
✅ Use TanStack Query for all API calls  
✅ Use Tailwind utility classes for styling (prefer theme colors like `-primary` instead of built-in colors)
✅ Use `@/` imports for absolute paths  
✅ Keep components simple and focused  
✅ Use FastEndpoints pattern for backend endpoints  
✅ Use bounded contexts for backend organization  
✅ Generate camelCase JSON from backend APIs  
✅ Name all FastEndpoints with `.WithName("camelCase")`
✅ Never automatically commit changes - always wait for explicit user instruction
✅ Pause after API edits for manual restart (Aspire workflow)
✅ Work on one realm (Backend/Frontend) at a time
✅ Prefer starting with Backend changes unless specified
✅ **Always use EF Core tools for migrations** - Use `dotnet ef migrations add` with MigrationService as startup project
✅ **Never manually create migration files** - If migration command fails, fix underlying issues first
✅ Prefer modern C# collection expressions (`[]`) when creating collection literals instead of `new List<> { }` or similar forms
✅ Assume a Windows development environment and provide PowerShell-compatible shell commands by default
✅ Use `npx apx-gen` to generate the API client(s) from the OpenAPI specification provided by the dotnet API(s).

### DON'T
❌ Don't use `any` type - use `unknown` if truly needed  
❌ Don't use const arrow functions for general function definitions (use named functions)  
❌ Don't manually edit files in `src/shared/clients/` (auto-generated)  
❌ Don't create abstractions prematurely  
❌ Don't add global state management (use React hooks + TanStack Query)  
❌ Don't use inline styles - use Tailwind classes  
❌ Don't create barrel exports (`index.ts` re-exports) unless truly needed  
❌ Don't add dependencies without justification  
❌ Don't mix business logic in React components
❌ Don't add any server functions or use any serverside functionality of the Tanstack Start framework. SPA, client code only!
❌ Don't build HTTP requests manually. Use apx.rest! You can run `npx apx-gen` to regenerate the client, which references the OpenAPI specification from the API(s)

## Code Patterns

### Frontend Component Template
```typescript
import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { useApiClient } from '@/shared/hooks/useApiClient'

export const Route = createFileRoute('/path')({
  component: ComponentName,
})

function ComponentName() {
  const client = useApiClient()
  
  const { data, isLoading } = useQuery({
    queryKey: ['key'],
    queryFn: async () => {
      const [result, response] = await client.method()
      if (!result) throw new Error('Failed')
      return result
    },
  })
  
  if (isLoading) return <div>Loading...</div>
  
  return (
    <div className="p-4">
      {/* JSX */}
    </div>
  )
}
```

### Backend Endpoint Template
```csharp
using FastEndpoints;

namespace Context.Application.Endpoints;

public class OperationName : Ep.Req<RequestDto>.Res<ResponseDto>
{
    public override void Configure()
    {
        Post("context/path");
        Description(b => b.WithName("operationName"));
        AllowAnonymous(); // or configure auth
    }

    public override async Task HandleAsync(RequestDto req, CancellationToken ct)
    {
        // Business logic here
        var response = new ResponseDto { /* ... */ };
        await Send.OkAsync(response, ct);
    }
}

public class RequestDto
{
    public string Property { get; set; } = string.Empty;
}

public class ResponseDto
{
    public string Result { get; set; } = string.Empty;
}

// All API responses should use envelope pattern with ___Response wrapper containing ResponseModel:
// Single item responses:
public class GetItemResponse
{
    public required ItemResponseModel Item { get; set; }
}

// List responses:
public class GetItemsResponse
{
    public required List<ItemResponseModel> Items { get; set; }
}

// Shared ResponseModels should be in [Module].Public/EndpointContracts/ for cross-module usage:
public class ItemResponseModel
{
    public required Guid Id { get; set; }
    public required string Name { get; set; }
}
```

## File Organization Hints

### Frontend
- **Routes**: `src/routes/*.tsx` - TanStack Router file-based routing
- **API Clients**: `src/lib/clients/` - AUTO-GENERATED, don't edit
- **Hooks**: `src/lib/hooks/` - Reusable React hooks
- **Utils**: `src/lib/utils/` - Pure utility functions
- **Modules**: `src/modules/[feature]/` - When feature needs 3+ files

### Backend
- **Endpoints**: `[Context].Application/Endpoints/` - FastEndpoints classes
- **Domain**: `[Context].Domain/Objects/` - Domain entities
- **Infrastructure**: `[Context].Infrastructure/Persistence/` - EF DbContext
- **Public**: `[Context].Public/Dtos/` - DTOs for inter-module communication. Modules should never reference each other directly, only via the Public layer.

## Naming Conventions

### Frontend
- Files: `kebab-case.tsx` or `PascalCase.tsx` for components
- Components: `PascalCase`
- Functions: `camelCase`
- Constants: `UPPER_SNAKE_CASE` or `camelCase`
- Types/Interfaces: `PascalCase`

### Backend
- Files: `PascalCase.cs`
- Classes: `PascalCase`
- Methods: `PascalCase`
- Properties: `PascalCase`
- Local variables: `camelCase`
- **DTOs**: Use `ResponseModel` suffix for API GET responses (e.g., `TriggerResponseModel`), not `Dto`
- **DTOs**: Use `Request`/`Response` suffixes for endpoint input/output classes

## Common Imports

### Frontend
```typescript
// React
import { useState, useEffect, useRef } from 'react'

// Routing
import { createFileRoute, useNavigate } from '@tanstack/react-router'

// Data fetching
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

// API Client
import { useApiClient } from '@/shared/hooks/useApiClient'

// Utils
import { cn } from '@/shared/lib/utils'
```

### Backend
```csharp
using FastEndpoints;
using Microsoft.EntityFrameworkCore;
using System.Threading;
using System.Threading.Tasks;
```

## Styling Guidelines
- Use Tailwind v4 utility classes
- Common patterns:
    - Layout: `flex`, `grid`, `container`
    - Spacing: `p-4`, `m-2`, `gap-4`
    - Colors: `bg-gray-100`, `text-blue-600`
    - Responsive: `sm:`, `md:`, `lg:` prefixes
- Use `cn()` utility for conditional classes:
  ```typescript
  className={cn('base-class', condition && 'conditional-class')}
  ```

## API Integration Flow
1. Backend: Create FastEndpoint in `[Context].Application/Endpoints/`
2. Backend: Use `.WithName("operationName")` in endpoint configuration
3. Backend: Ensure DTOs serialize to camelCase JSON
4. Frontend: Regenerate API client:
    - Ensure API is running and updated
    - Run `npx apx-gen` in `[Project].Web`
    - (apx.rest will pick up OpenAPI changes from live API)
5. Frontend: Use `useApiClient()` (or similar) + TanStack Query to call endpoint

## EF Core Migrations

**CRITICAL**: Never manually create migration files. Always use EF Core tools.

### Creating Migrations
```bash
# Always use [Project].MigrationService as startup project
cd [SolutionRoot]
dotnet ef migrations add MigrationName \
  --project [Module].Infrastructure \
  --startup-project [Project].MigrationService \
  --context [Module]DbContext
```

**Example:**
```bash
dotnet ef migrations add InitialCreate \
  --project [Module].Infrastructure \
  --startup-project [Project].MigrationService \
  --context [Module]DbContext
```

### Troubleshooting Failed Migrations
If `dotnet ef migrations add` fails:
1. ✅ Check DbContext has proper constructor accepting `DbContextOptions<T>`
2. ✅ Verify `ApplyConfigurationsFromAssembly` is used in `OnModelCreating`
3. ✅ Ensure entity configurations implement `IEntityTypeConfiguration<T>`
4. ✅ Confirm Infrastructure project has all required EF packages
5. ✅ Verify MigrationService references the Infrastructure project
6. ✅ Check for compilation errors in Domain/Infrastructure projects

**Do NOT**: Create migration files manually or copy from other modules. Fix the root cause instead.

### Migration Location
- Migrations should be in `[Module].Infrastructure/Persistence/Migrations/`
- Namespace should be `[Module].Infrastructure.Persistence.Migrations`
- If migrations appear at wrong location, the DbContext likely has incorrect configuration

## Error Handling

### Frontend
```typescript
const { data, error, isLoading } = useQuery({
  queryKey: ['key'],
  queryFn: async () => {
    const [result, response] = await client.method()
    if (!result) {
      throw new Error(response.statusText || 'Request failed')
    }
    return result
  },
})

if (error) return <div>Error: {error.message}</div>
```

### Backend
```csharp
public override async Task HandleAsync(CancellationToken ct)
{
    try
    {
        // Logic
        await Send.OkAsync(result, ct);
    }
    catch (Exception ex)
    {
        await Send.ErrorsAsync(statusCode: 500, ct);
    }
}
```

## TypeScript Tips
- Use `satisfies` for type checking without widening:
  ```typescript
  const config = { ... } satisfies Config
  ```
- Prefer `interface` for public APIs, `type` for unions/intersections
- Use `as const` for literal types:
  ```typescript
  const statuses = ['pending', 'active'] as const
  ```

## Performance Hints
- **Frontend**: TanStack Query handles caching - don't over-optimize
- **Backend**: Avoid N+1 queries - use `.Include()` or `.Select()` projections
- **MVP Focus**: Only optimize what's actually slow

## Testing Reminders
- Tests not yet implemented in MVP
- Keep code testable: pure functions, dependency injection
- When adding tests later: Vitest (frontend), xUnit (backend)

## When Suggesting Code
1. **Keep it simple**
2. **Follow existing patterns** in the codebase
3. **Use established libraries** - don't reinvent wheels unless we need to
4. **Type everything** - leverage TypeScript/C# type systems
5. **Stay in scope** - don't suggest major refactors unless asked

## Environment Variables
- Frontend: Use `import.meta.env.VITE_*` (Vite convention)
- Backend: Use `IConfiguration` injected from DI
- Never hardcode URLs or secrets

## Quick Reference
- **Lint/Format**: `npm run check`
- **Build**: `npm run build`
- **Backend run**: `dotnet run --project [Project].AppHost`

---

💡 **Remember**: Prefer working code over perfect architecture. Iterate fast!