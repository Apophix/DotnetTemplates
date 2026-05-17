# WebProject Solution Template

A full-stack solution template built for rapid development with a clean modular backend and a React SPA frontend.

---

## Solution Structure

```
/Common/                        Shared libraries used across all modules
  Common.Library.Api            API defaults, global exception handler, FastEndpoints helpers, OpenAPI extensions
  Common.Library.DevSeeder      Development data seeding helpers
  Common.Library.Logging        Serilog configuration (console + Seq)

/Modules/{ModuleName}/          One folder per bounded context
  {Module}.Domain               Entities and domain logic
  {Module}.Application          FastEndpoints, application services
  {Module}.Infrastructure       EF Core DbContext, entity configurations, migrations
  {Module}.Public               DTOs shared with other modules (only cross-module reference allowed)
  {Module}.Tests                Unit + integration tests

/Tests/
  FitnessTests                  Architecture rule enforcement (see below)

WebProject.Api                  API entry point — thin Program.cs
WebProject.AppHost              Aspire orchestration (database, Seq, frontend, API)
WebProject.MigrationService     EF Core design-time host for running migrations
WebProject.ServiceDefaults      Aspire shared service defaults (OpenTelemetry, health checks)
WebProject.Web                  React SPA frontend
```

---

## Backend

- **.NET 10** Web API
- **Aspire** orchestration with persistent containers (no re-pull on restart)
- **FastEndpoints** for endpoint definition
- **OpenAPI 3.0** with [apx.rest](https://github.com/Apophix/apx.rest) client generation
- **EF Core** with **PostgreSQL** (default) or **SQL Server** (swap two lines in `AppHost.cs`)
- **Serilog** structured logging — console + Seq sink (auto-wired when Seq connection string present)
- **Global exception handler** — maps common exception types to HTTP status codes
- **Centralized package management** via `Directory.Packages.props`

### Running the API

```bash
dotnet run --project WebProject.AppHost
```

Aspire will start PostgreSQL and Seq as persistent Docker containers on first run (requires Docker). Subsequent runs reuse the existing containers.

> **Seq** is skipped if port `5341` is already in use (i.e. a local Seq instance is running).

### Switching Database Provider

In `WebProject.AppHost/AppHost.cs`, comment the Postgres lines and uncomment SQL Server:

```csharp
// var database = builder.AddPostgres("postgres")...
var database = builder.AddSqlServer("sqlserver")
                      .WithLifetime(ContainerLifetime.Persistent)
                      .WithDataVolume()
                      .AddDatabase("app-db");
```

The connection string name `"app-db"` stays the same — nothing else changes.

### Adding a Module

1. Create `{Module}.Domain`, `{Module}.Application`, `{Module}.Infrastructure`, `{Module}.Public`, `{Module}.Tests` projects under `/Modules/{Module}/`
2. Add them to `WebProject.slnx` under a `/Modules/{Module}/` folder
3. Add an `AddSampleInfrastructure()` extension in Infrastructure and an `Add{Module}Application()` extension in Application
4. Register in `WebProject.Api/Program.cs`: `builder.Services.Add{Module}Application();`

### EF Core Migrations

```bash
dotnet ef migrations add <MigrationName> \
  --project {Module}.Infrastructure \
  --startup-project WebProject.MigrationService \
  --context {Module}DbContext
```

---

## Architecture Rules

`FitnessTests` enforces the rule that **module projects may only reference other modules via their `.Public` project** — never `.Domain`, `.Application`, or `.Infrastructure` directly.

The test runs on every build/CI and fails with a list of violations if the rule is broken.

---

## Configuration as Code

All application configuration lives in `config/` — always, regardless of which infrastructure path you choose.

| File | Purpose |
|---|---|
| `appconfig.yaml` | Non-secret settings, organized by environment (`shared`, `staging`, `production`) |
| `featureflags.yaml` | Feature flag definitions with per-environment initial states |
| `gen-appsettings.cs` | Script that reads both files and generates `appsettings.{Env}.json` |
| `user-secrets.example.json` | Documents which secrets are required locally; used by `dev-hydrate.ps1` |

`gen-appsettings.cs` is the single tool for all infra paths. The output format and how secrets are handled differs by path:

### No Azure (Aspire / Docker Compose)

Plain values only — no Key Vault references. Generate and commit the files:

```bash
dotnet run config/gen-appsettings.cs -- --env staging    --output MyApp.Api/appsettings.Staging.json
dotnet run config/gen-appsettings.cs -- --env production --output MyApp.Api/appsettings.Production.json
```

Secrets are injected at deploy time via environment variables (CI/CD secrets → container env or App Service application settings).

### Azure App Service

Mark secrets in `appconfig.yaml` with `keyVaultSecret:` instead of a plain value:

```yaml
staging:
  ConnectionStrings:Default:
    keyVaultSecret: connection-string-staging   # name of the secret in Key Vault
```

Then generate with your vault name:

```bash
dotnet run config/gen-appsettings.cs -- --env staging --vault kv-myapp-stg-xxxx \
  --output MyApp.Api/appsettings.Staging.json
```

The generated file contains Azure Key Vault reference URIs (`@Microsoft.KeyVault(...)`), not raw secret values — safe to review, but **do not commit** (the file is gitignored; CI regenerates it at build time). App Service resolves the Key Vault URIs at runtime via the managed identity provisioned by `infra/azure-app-service/`.

```bash
# Deploy or update infrastructure
./infra/azure-app-service/deploy.sh --location eastus
```

### Azure Container Apps

Identical config workflow to App Service — same YAML files, same `gen-appsettings.cs` script, same Key Vault reference format. The managed identity is provisioned by `infra/azure-container-apps/`.

```bash
dotnet run config/gen-appsettings.cs -- --env staging --vault kv-myapp-stg-xxxx \
  --output MyApp.Api/appsettings.Staging.json

./infra/azure-container-apps/deploy.sh --location eastus
```

### Local dev

Local config is not generated — it lives in `appsettings.local.json` (gitignored, created by `dev-setup.ps1` from the `.example` file). Edit it directly. Feature flags and settings that need to match a deployed environment can be pulled from Azure Key Vault:

```powershell
.\scripts\dev-hydrate.ps1
```

---



- **TanStack Start** in SPA mode (no SSR / server functions)
- **TanStack Router** for file-based routing
- **TanStack Query** for all data fetching
- **[apx.rest](https://github.com/Apophix/apx.rest)** auto-generated API client

### Regenerating the API client

With the API running:

```bash
cd WebProject.Web
npx apx-gen
```

---

## Testing

Module test projects (`{Module}.Tests`) combine unit and integration tests:

- **[Shouldly](https://github.com/shouldly/shouldly)** for fluent assertions
- **[Verify](https://github.com/VerifyTests/Verify)** for snapshot assertions
- **[Testcontainers](https://dotnet.testcontainers.org/)** for real PostgreSQL integration tests (requires Docker)

```bash
# Unit tests only (no Docker required)
dotnet test {Module}.Tests --filter "FullyQualifiedName~Unit"

# All tests
dotnet test {Module}.Tests
```

---

## Installation

```bash
git clone <repo>
cd WebProject
dotnet new install .
```
