# Template Audit

> Audited: 2026-04-25  
> Scope: security, developer experience, infrastructure soundness, code quality, misc

Severity legend: 🔴 Critical · 🟠 High · 🟡 Medium

---

## Security

### 🔴 `appsettings.Staging.json` has `DevBypass.Enabled: true`

`DevAuthMiddleware` only blocks the bypass when `env.IsProduction()`, so the dev auth bypass is
**active on staging**. Anyone who knows the `X-Dev-Persona` header can impersonate any configured
persona. `appsettings.Staging.json` should set `"Enabled": false`.

### 🟠 CORS hardcodes `http://localhost:3000` unconditionally in all environments

`ApiExtensions.cs` always adds `localhost:3000` to the allowed origins set regardless of
environment. In production the Aspire service URL is added dynamically, which is correct — but
`localhost:3000` should only be permitted in `Development`.

### 🟡 `GetFeatureFlagsEndpoint` is `AllowAnonymous` and publicly enumerates internal config

`/feature-flags` returns all flag names and their enabled state to anyone. Flag names aren't
secrets, but exposing the internal feature roadmap without authentication is unnecessary. Consider
restricting to authenticated users or an admin role.

### 🟡 Dockerfile has no `.dockerignore`

The build stage does `COPY . .`, pulling the entire repo context into the image — including
`appsettings.Development.json`, dev tooling, and test outputs. The final `aspnet` stage only
contains the published output, but the intermediate build layer is bloated and sensitive dev files
are technically present in it. A `.dockerignore` is missing.

---

## Developer Experience

### 🔴 Instructions reference file paths and a hook that don't exist in the codebase

`frontend.instructions.md` refers to:
- `src/shared/clients/` (auto-generated)
- `src/shared/hooks/`
- `src/shared/lib/`
- `useApiClient()` hook

The actual code lives at `src/lib/clients/`, `src/lib/hooks/`, and **there is no `useApiClient()` hook** —
clients are instantiated with `new MyApiClient()` directly. This is the highest-impact DX issue
because it will actively mislead both Copilot and developers following the instructions.

### 🟠 Demo code directly contradicts the project's stated SPA-only stance

`frontend.instructions.md` explicitly says: *"SPA mode only — never use server functions or any
server-side TanStack Start features."* The demo at `start.server-funcs.tsx` uses `createServerFn`,
reads/writes `todos.json` on the server filesystem with no input validation, and is linked from
the main nav. This sends mixed signals about which patterns to follow.

### 🟠 `CheckoutServiceResolver.Variant` always returns the legacy variant regardless of flag state

```csharp
public string Variant => _legacy.Variant; // resolved lazily per-call below
```

The comment says "resolved lazily" but `Variant` permanently returns `_legacy.Variant`.
`GetSummaryAsync` delegates correctly, so the bug is invisible at runtime — but developers
modeling their own resolvers will copy this pattern and silently expose the wrong variant on the
property.

### 🟡 Homepage (`/`) is the generic TanStack Start boilerplate

The index route still shows TanStack logos, "The framework for next generation AI applications"
copy, and a link to `https://tanstack.com/start`. A developer cloning this template may not
immediately recognise this as scaffold boilerplate to delete. A minimal neutral placeholder with
links to the demo pages would signal intent more clearly.

### 🟡 `dev` script port and `vite.config.ts` PORT env logic are inconsistent

`package.json`: `"dev": "vite dev --port 3000"` — hardcodes 3000 at CLI.  
`vite.config.ts`: `port: Number(process.env['PORT'] ?? 5173)` — reads a `PORT` env var.

The CLI flag takes precedence over the config file, so `process.env.PORT` is never consulted
during `npm run dev`. The two configurations imply different canonical ports.

### 🟡 `eslint.config.js` silences `no-explicit-any` and `no-non-null-assertion` project-wide

These are disabled globally, not just for the generated client file (which already carries
`/* eslint-disable */`). Allowing `any` freely across the entire project undermines the strict
TypeScript config and creates a broad escape hatch that tends to proliferate.

---

## Infrastructure Soundness

### 🔴 Health endpoints only exposed in `Development` — staging smoke tests will 404

`ServiceDefaults/Extensions.cs` gates `/health` and `/alive` behind
`app.Environment.IsDevelopment()`. The deploy pipeline smoke-tests staging under
`ASPNETCORE_ENVIRONMENT=Staging`, so `/health` has no registered route and will return 404.
This causes the `smoke-test` job and the *"Wait for staging slot to be healthy before swap"* step
to always fail. Either expose `/health` in non-dev environments or update the CI probe.

### 🟠 `AppHost.cs` double-applies `.WaitFor(database)` and `.WithReference(database)` on the API

```csharp
// Line 26-28
var api = builder.AddProject<Projects.WebProject_Api>("api")
    .WaitFor(database)
    .WithReference(database);

// Line 37 — redundant
api.WithReference(database).WaitFor(database);
```

The second call is dead configuration. Aspire ignores it silently, but it adds noise and can
confuse developers editing the AppHost.

### 🟡 `IsPortInUse()` catches all exceptions instead of only `SocketException`

A bare `catch` absorbs access-denied errors, DNS failures, etc., and returns `false` in all cases.
Should catch `SocketException` specifically (connection refused = port not in use) and rethrow
anything else.

### 🟡 `IsPortInUse()` is an unreliable proxy for "Seq is running"

If port 5341 is taken by anything other than Seq, Aspire silently skips the container and the API
loses its log sink. A user-controlled opt-out (e.g., a user-secrets or environment variable flag
like `ASPIRE_SKIP_SEQ`) would be more predictable than a TCP probe.

### 🟡 EF Core 9 on a .NET 10 project

`Directory.Packages.props` pins `Microsoft.EntityFrameworkCore 9.0.2` and
`Npgsql.EntityFrameworkCore.PostgreSQL 9.0.4` while the project targets .NET 10 and uses
`Microsoft.Extensions.Hosting 10.0.3`. EF Core 10 is available and targets .NET 10 natively.
Not a blocker, but the version skew may generate compatibility warnings as the ecosystem
settles.

### 🟡 `MigrationWorker` uses `AppDomain` assembly scanning to discover DbContexts and seeders

Discovery via `AppDomain.CurrentDomain.GetAssemblies()` only finds assemblies already loaded at
that point in the runtime. In some host configurations a module's assembly may not have been
loaded yet, silently skipping its migrations. Explicit DI registration (register types, resolve
`IEnumerable<T>`) would be deterministic in ordering and more discoverable.

---

## Code Quality

### 🟡 `SampleItem.CreatedAt` (and `SampleItemDto.CreatedAt`) use `DateTime` not `DateTimeOffset`

`DateTime` is timezone-ambiguous. A developer writing `DateTime.Now` instead of
`DateTime.UtcNow` will silently store local time. `DateTimeOffset` is the correct idiom for
stored timestamps and aligns with Npgsql's mapping conventions.

### 🟡 Both `AddDbContext` and `AddDbContextFactory` registered for the same context

`Sample.Infrastructure/Extensions.cs` registers both `AddDbContext<SampleDbContext>` (scoped) and
`AddDbContextFactory<SampleDbContext>` (also scoped). These largely overlap; having both is
unnecessary unless background/parallel-access patterns are explicitly needed and documented.

### 🟡 `SampleUnionEndpoint` allocates `new Random()` per request

`Random.Shared` (available since .NET 6) is thread-safe and allocation-free.
`new Random()` per call is the old pattern.

### 🟡 `useStreamedRequest.ts` stores error as `unknown` but returns it typed as `Error`

```ts
const [error, setError] = useState<unknown>(null);
// ...
error: error ? (error as Error) : null,  // cast bypasses type safety
```

The state accepts any thrown value but the hook's return type promises `Error | null`. Callers can
receive a non-`Error` object silently cast to `Error`. Should narrow properly or widen the return
type to `unknown`.

### 🟡 JSON serialization configured in two places with no explanation

`ApiExtensions.cs` configures camelCase + `JsonStringEnumConverter` in both
`builder.Services.Configure<JsonOptions>` (ASP.NET Core pipeline) and
`app.UseFastEndpoints(c => c.Serializer.Options...)` (FastEndpoints pipeline). This is intentional
because FastEndpoints uses its own serializer, but without a comment it looks like accidental
duplication that a future developer might "fix" by removing one.

### 🟡 `CompoundFlagPanel` demo uses identity operations as placeholders

```tsx
const bothOn = isEnabled && isEnabled   // replace second isEnabled with another flag
const eitherOn = isEnabled || false     // replace false with another flag
```

`isEnabled && isEnabled` and `isEnabled || false` are no-ops. No lint rule flags them, so the
placeholder state is invisible without reading the code carefully.

### 🟡 `SampleService.cs` constructs a hardcoded entity with no DB interaction

The public-layer service builds a `SampleItem` in-memory rather than querying the database. The
comment acknowledges this, but it means the sample doesn't demonstrate the full stack path through
`SampleDbContext`. Even a basic `FindAsync` call would make it a more useful reference.

---

## Misc

- **Empty `/Modules/` solution folder** in `WebProject.slnx` implies future modules without any
  stub or guidance comment.

- **`todos.json` in the working tree** is written at runtime by the server-funcs demo. It is
  gitignored, but should be deleted from the working tree before distributing the template so new
  clones start clean.

- **`SampleItemDto.cs` has an unresolved naming debate as a code comment** — internal deliberation
  over "Dto" vs "Mto" vs dropping the suffix shouldn't live in distributed template code.

- **`DatabaseFixture` uses `EnsureCreatedAsync()` instead of `MigrateAsync()`** — `EnsureCreated`
  bypasses the migrations pipeline and creates the schema directly from the model, diverging from
  the production path. `MigrateAsync()` would be more consistent and exercises real migration files.

- **`deploy.yml` runs `npm ci` twice** (once for the staging build, once for the production build).
  Only `npm run build` needs to run twice (with different `VITE_API_BASE_URL` values); the install
  step could be extracted into a shared setup step or a matrix to halve install time.

- **No `staticwebapp.config.json`** in `WebProject.Web/public/` — no custom routing rules,
  security headers (`X-Frame-Options`, `Content-Security-Policy`, etc.), or `robots.txt` are
  configured for the Azure Static Web App deployment.
