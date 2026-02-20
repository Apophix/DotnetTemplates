# WebProject Solution Template

A full-stack solution template built for rapid development with a clean modular backend and a React SPA frontend.

---

## Solution Structure

```
/Common/                        Shared libraries used across all modules
  Common.Library.Api            API defaults: JSON, CORS, FastEndpoints, OpenAPI, global exception handler
  Common.Library.DevSeeder      Development data seeding helpers
  Common.Library.Endpoints      FastEndpoints base classes and OpenAPI helpers
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
- **OpenAPI 3.0** with [apx.rest](https://apx.rest) client generation
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

## Frontend

- **TanStack Start** in SPA mode (no SSR / server functions)
- **TanStack Router** for file-based routing
- **TanStack Query** for all data fetching
- **[apx.rest](https://apx.rest)** auto-generated API client

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
