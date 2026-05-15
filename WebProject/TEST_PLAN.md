# WebProject Template — Manual Test Plan

A comprehensive checklist for validating every aspect of the template.
Tests are ordered from most foundational to most complex.
**Every suite begins by scaffolding a fresh project from the template.**

---

## How to use this document

- Work through suites in order — later suites build on earlier ones.
- Each suite is self-contained: scaffold a new project, run the checks, discard the project.
- Mark each item `[x]` as you verify it.
- Record failures with a note inline.

### Common setup (install template once)

```bash
# From the repo root — installs the template from source
dotnet new install .

# Verify it appears
dotnet new list webproject
```

---

## Suite 1 — Minimal Scaffold (No Azure)

> Tests the base template with no infrastructure options. This is what a developer gets when they
> just want to start coding without committing to any cloud provider.

### 1.1 Scaffold

```bash
dotnet new webproject -n MyApp -o MyApp
cd MyApp
```

- [ ] Command exits 0
- [ ] Solution file `MyApp.slnx` (or `MyApp.sln`) present at root
- [ ] No `.github/` folder created
- [ ] No `infra/` folder created
- [ ] No `config/` folder created
- [ ] All projects renamed: `WebProject.*` → `MyApp.*`, `Sample.*` unchanged
- [ ] All namespace references updated (spot-check `MyApp.Api/Program.cs`)

### 1.2 Developer setup script

```powershell
.\scripts\dev-setup.ps1
```

- [ ] Prerequisite checks pass (dotnet, node, docker)
- [ ] `dotnet restore` completes without errors
- [ ] `npm ci` inside `MyApp.Web` completes without errors
- [ ] `.env.local` created from `.env.example` in `MyApp.Web`
- [ ] User secrets check runs; lists any missing secrets with clear guidance
- [ ] Script is idempotent — running it twice produces no errors

### 1.3 Unit and fitness tests

```bash
dotnet test MyApp.slnx --configuration Release --filter "FullyQualifiedName!~Integration"
```

- [ ] All unit tests pass
- [ ] Architecture / fitness tests pass (module reference rules enforced)
- [ ] Zero compilation errors

### 1.4 Aspire local development startup

```bash
dotnet run --project MyApp.AppHost
```

- [ ] Aspire dashboard opens (default: https://localhost:15888)
- [ ] Dashboard shows: `MyApp.Api`, `MyApp.Web`, `MyApp.MigrationService`, `database`
- [ ] `MyApp.MigrationService` runs to completion (exit 0) — migrations applied
- [ ] `MyApp.Api` reaches healthy state — `/health` returns 200
- [ ] `MyApp.Web` (Vite dev server) starts — frontend accessible in browser
- [ ] No "unhealthy" services after 60 seconds

### 1.5 Frontend — baseline

Open the frontend URL from the Aspire dashboard.

- [ ] Root `/` route loads — "your project starts here" landing page renders
- [ ] No console errors in browser devtools
- [ ] No broken network requests
- [ ] `@tanstack/react-devtools` panel does NOT appear (SPA mode, dev build — verify DEV gate works OR confirm it appears in dev only and is absent in prod build per 1.8)

### 1.6 Feature flags demo

Navigate to `/demo/feature-flags`.

- [ ] Page loads without errors
- [ ] Feature flag state is fetched from the API (`GET /api/feature-flags` or similar)
- [ ] `ExampleFlag` is displayed with its current value (false in production config, true in staging)
- [ ] Changing flag value in `config/featureflags.yaml` and restarting API reflects in the UI

### 1.7 Authentication — dev login panel

- [ ] Dev login panel renders on the index page (or accessible from it)
- [ ] "Login as User" button is visible
- [ ] "Login as Admin" button is visible
- [ ] Clicking "Login as User" completes PKCE flow and redirects to authenticated home
- [ ] `useApiClient()` hook includes `Authorization: Bearer <token>` on subsequent API calls (verify in devtools Network tab)
- [ ] Clicking "Login as Admin" works the same way
- [ ] Auth state persists across page reload (silent refresh via `HttpOnly` refresh token cookie)
- [ ] Logout clears in-memory token and redirect to unauthenticated state

### 1.8 Role-based access

- [ ] Navigate to `/demo/protected` — redirected to login when not authenticated
- [ ] Log in as `user@localhost` — access granted to User-level protected route
- [ ] Log in as `admin@localhost` — access granted to Admin-level protected route
- [ ] API endpoint decorated with `[Authorize(Roles = "Admin")]` returns 403 when called with User token
- [ ] API endpoint decorated with `[Authorize(Roles = "Admin")]` returns 200 when called with Admin token

### 1.9 `usePublicApiClient()` — anonymous calls

- [ ] Feature flags endpoint is called without an `Authorization` header (public)
- [ ] Calling a protected endpoint via `usePublicApiClient()` returns 401 (correct — no token)

### 1.10 Frontend production build

```bash
cd MyApp.Web
npm run build
```

- [ ] Build exits 0
- [ ] `dist/client/` directory produced
- [ ] `@tanstack/react-devtools` is NOT present in the built bundle (tree-shaken)
- [ ] No TypeScript errors
- [ ] Bundle size is reasonable — no accidental inclusion of dev-only packages

### 1.11 Integration tests

Requires Docker running.

```bash
dotnet test MyApp.slnx --configuration Release --filter "FullyQualifiedName~Integration"
```

- [ ] PostgreSQL Testcontainer spins up
- [ ] Migrations applied via `MigrateAsync()` (not `EnsureCreatedAsync`)
- [ ] Repository tests pass against real database
- [ ] Container cleaned up after tests

### 1.12 `SampleItem` entity correctness

- [ ] `SampleItem.CreatedAt` is `DateTimeOffset` (not `DateTime`)
- [ ] `SampleItemDto.CreatedAt` is `DateTimeOffset`
- [ ] Round-trip: create item → retrieve item → `CreatedAt` preserves offset

### 1.13 Docker Compose — local dev

```bash
docker compose --file infra/containers-generic/docker-compose.yml up --build
```

- [ ] SQL Server container starts and passes health check
- [ ] API container builds and starts; `/alive` returns 200
- [ ] Frontend container builds (nginx) and serves on port 5173
- [ ] Migrations do NOT run automatically via this compose file (documented limitation — use Aspire or run manually)
- [ ] `docker compose down -v` cleans up all volumes

---

## Suite 2 — App Service Scaffold

> Tests the template with Azure App Service infrastructure. Requires Azure CLI and an active subscription for the infra sub-suites.

### 2.1 Scaffold with App Service option

```bash
dotnet new webproject -n MyApp -o MyApp \
  --UseAzureAppServiceInfra \
  --AzureResourcePrefix myapp
cd MyApp
```

- [ ] Command exits 0
- [ ] `.github/workflows/` present with: `staging.appservice.yml`, `staging-nuke.appservice.yml`, `deploy.appservice.yml`, `infra.yml`
- [ ] `.github/workflows/staging.aca.yml` NOT present
- [ ] `infra/azure-app-service/` present: `main.bicep`, `main.bicepparam`, `README.md`
- [ ] `infra/containers-generic/` present: `docker-compose.yml`, `docker-compose.prod.yml`, `README.md`
- [ ] `config/gen-appconfig.cs` present (or `gen-appsettings.cs`)
- [ ] `config/appconfig.yaml` and `config/featureflags.yaml` present
- [ ] All resource name placeholders replaced: `webprojectazureprefix` → `myapp` throughout Bicep and workflow files
- [ ] `WebProject.Api/Dockerfile` NOT present (App Service variant doesn't containerize the API)

### 2.2 Config generation

```bash
dotnet run config/gen-appsettings.cs -- --env staging --output MyApp.Api/appsettings.Staging.json
dotnet run config/gen-appsettings.cs -- --env production --output MyApp.Api/appsettings.Production.json
```

- [ ] Staging generation exits 0
- [ ] `MyApp.Api/appsettings.Staging.json` created with valid JSON
- [ ] `ExampleFlag` appears under `FeatureManagement` with value `true` in staging
- [ ] Production generation exits 0
- [ ] `MyApp.Api/appsettings.Production.json` created with valid JSON
- [ ] `ExampleFlag` value is `false` in production
- [ ] Both files are gitignored — `git status` shows them as ignored

### 2.3 All Suite 1 local dev checks apply

Re-run the following from Suite 1 against this scaffold:

- [ ] 1.2 dev-setup.ps1
- [ ] 1.3 unit + fitness tests
- [ ] 1.4 Aspire startup
- [ ] 1.5–1.10 frontend and auth
- [ ] 1.11 integration tests

### 2.4 Workflow syntax validation

```bash
# Install actionlint or use GitHub CLI
gh workflow list
# OR locally:
find .github/workflows -name '*.yml' -exec actionlint {} \;
```

- [ ] `staging.appservice.yml` — no syntax errors; `sync-appconfig.sh` NOT referenced
- [ ] `staging-nuke.appservice.yml` — no syntax errors
- [ ] `deploy.appservice.yml` — no syntax errors; `sync-appconfig.sh` NOT referenced
- [ ] `infra.yml` — no syntax errors
- [ ] Every workflow references `webprojectazureprefix` nowhere (all replaced with `myapp`)
- [ ] `gen-appsettings.cs` step appears before publish/build steps in all deploy workflows

### 2.5 Bicep validation (requires Azure CLI)

```bash
az bicep build --file infra/azure-app-service/main.bicep
```

- [ ] Bicep compiles without errors
- [ ] `main.bicepparam` parameter names match `main.bicep` parameter declarations
- [ ] `az stack` command in `infra/azure-app-service/README.md` matches the actual file structure
- [ ] `--action-on-unmanage detachAll` (not `deleteAll`) in any documented `az stack` commands

### 2.6 Azure infrastructure deployment (requires active subscription)

```bash
# Follow infra/azure-app-service/README.md bootstrap steps
./infra/bootstrap.ps1   # or bootstrap.sh
```

- [ ] Bootstrap script provisions: App Service Plan, App Service (API), SWA, Key Vault, SQL Server, Managed Identity
- [ ] No `app-configuration` resource provisioned
- [ ] Key Vault has `CanNotDelete` lock on database and Key Vault resources
- [ ] Managed Identity has correct role assignments (KV Secrets User, SQL contributor)
- [ ] `az stack show` shows all resources in the stack

### 2.7 Production deploy workflow (requires GitHub + Azure)

Trigger `deploy.appservice.yml` on `main` push.

- [ ] `build` job: restore → test → gen-appsettings (production) → publish API → publish migration → build frontend → upload artifacts
- [ ] `migrate-prod` job: downloads migration artifact, runs `dotnet MyApp.MigrationService.dll`, exits 0
- [ ] `deploy-prod` job: downloads API + web artifacts, deploys API to App Service, deploys SWA
- [ ] API health check passes post-deploy
- [ ] `appsettings.Production.json` values are visible in running API (`/api/feature-flags` returns production flag values)
- [ ] CORS does not block frontend origin

### 2.8 Staging deploy workflow

Trigger `staging.appservice.yml` on a PR or push.

- [ ] Merge step: main + all open PRs merged in chronological order
- [ ] PRs with conflicts are skipped; status check failure posted on those PRs
- [ ] `gen-appsettings` step generates `appsettings.Staging.json` before publish
- [ ] Migration runs against staging database
- [ ] API deployed to staging App Service
- [ ] SWA staging environment deployed
- [ ] Health endpoint `/health` responds 200 in staging
- [ ] Dev login panel is visible in staging frontend
- [ ] PR summary comment posted: ✅ included / ⚠️ skipped

### 2.9 Nightly staging reset

Trigger `staging-nuke.appservice.yml` (or wait for scheduled run).

- [ ] Staging database dropped and recreated
- [ ] All migrations applied from scratch
- [ ] DevSeeder re-runs: `admin@localhost` and `user@localhost` accounts exist
- [ ] Current staging build redeployed (no new merge)
- [ ] GitHub Actions job summary posted with migration list and seed row counts

---

## Suite 3 — Container Apps Scaffold

> Tests the ACA variant. Requires Docker, Azure CLI, and an ACR for the infra sub-suites.

### 3.1 Scaffold with ACA option

```bash
dotnet new webproject -n MyApp -o MyApp \
  --UseAzureContainerInfra \
  --AzureResourcePrefix myapp
cd MyApp
```

- [ ] Command exits 0
- [ ] `.github/workflows/` present with: `staging.aca.yml`, `staging-nuke.aca.yml`, `deploy.aca.yml`, `infra.yml`
- [ ] `staging.appservice.yml` NOT present
- [ ] `infra/azure-container-apps/` present: `main.bicep`, `main.bicepparam`, `README.md`
- [ ] `WebProject.Api/Dockerfile` present
- [ ] Bootstrap and deploy scripts present (`bootstrap.ps1`, `bootstrap.sh`, `deploy.ps1`, `deploy.sh`)
- [ ] `AzureResourcePrefix` token replaced: `webprojectazureprefix` → `myapp`

### 3.2 Dockerfile build

```bash
# From repo root (Dockerfile uses full repo context)
docker build -f MyApp.Api/Dockerfile -t myapp-api:test .
```

- [ ] Build exits 0
- [ ] Image size is reasonable (multi-stage build — final stage is runtime only)
- [ ] `docker run --rm -e ASPNETCORE_ENVIRONMENT=Development -p 8080:8080 myapp-api:test` starts without crash
- [ ] `/alive` returns 200

### 3.3 gen-appsettings for ACA

```bash
dotnet run config/gen-appsettings.cs -- --env staging --output MyApp.Api/appsettings.Staging.json
docker build -f MyApp.Api/Dockerfile -t myapp-api:staging .
```

- [ ] `appsettings.Staging.json` present before `docker build`
- [ ] Staging build exits 0
- [ ] Running the staging image: `ASPNETCORE_ENVIRONMENT=Staging` — feature flags reflect staging values

### 3.4 Workflow syntax validation

- [ ] `staging.aca.yml` — no syntax errors; `sync-appconfig.sh` NOT referenced
- [ ] `staging-nuke.aca.yml` — no syntax errors
- [ ] `deploy.aca.yml` — no syntax errors; `sync-appconfig.sh` NOT referenced
- [ ] `gen-appsettings.cs` step appears before `docker build` in all ACA deploy workflows
- [ ] `ConnectionStrings__app-db` (with hyphen) handled with `env "ConnectionStrings__app-db=..."` pattern in migration steps

### 3.5 Docker Compose production variant

```bash
# Create a .env file with required vars
cat > .env << EOF
REGISTRY=localhost:5000
IMAGE_TAG=test
MSSQL_SA_PASSWORD=YourStr0ng!Passw0rd
DB_CONN=Server=tcp:db,1433;Initial Catalog=myapp;User ID=sa;Password=YourStr0ng!Passw0rd;Encrypt=True;TrustServerCertificate=True;
EOF

docker compose --file infra/containers-generic/docker-compose.prod.yml up
```

- [ ] Compose file parses correctly (`docker compose config --file ...` exits 0)
- [ ] Missing `REGISTRY` or `IMAGE_TAG` produces a clear error (required var syntax)
- [ ] `restart: unless-stopped` present on API and web services
- [ ] Production environment (`ASPNETCORE_ENVIRONMENT: Production`) set on API service

### 3.6 Azure infrastructure deployment — ACA (requires active subscription + ACR)

Follow `infra/azure-container-apps/README.md`.

- [ ] Bootstrap script provisions: ACA Environment, ACA App (API), SWA, ACR, Key Vault, SQL Server (or PostgreSQL), Managed Identity
- [ ] No `app-configuration` resource provisioned
- [ ] ACA health probe hits `/health` successfully
- [ ] Container scaling min/max replicas configured
- [ ] Key Vault secrets resolved as environment variables in ACA app

### 3.7 ACA staging deploy and nuke workflows

- [ ] `staging.aca.yml` triggers on PR/push; merged build image pushed to ACR
- [ ] API image tagged with `github.sha`
- [ ] `staging-nuke.aca.yml` scales ACA to 0 replicas, recreates database, scales back up
- [ ] Dev login panel visible at staging URL

---

## Suite 4 — Developer Workflow Extensions

> Tests common day-to-day development tasks a developer would perform against the template.

### 4.1 Adding a new API endpoint

```bash
dotnet new webproject -n MyApp -o MyApp
cd MyApp
```

- [ ] Create a new FastEndpoints endpoint (e.g., `GET /api/products`)
- [ ] Add to `WebProject.Api` project; endpoint resolves from DI
- [ ] Aspire restart picks up new endpoint
- [ ] `dotnet test` still passes (unit + fitness tests)
- [ ] Fitness tests enforce module reference rules — new endpoint doesn't violate architecture constraints

### 4.2 Regenerating the API client

```bash
cd MyApp.Web
npx apx-gen   # or the documented command
```

- [ ] Client regeneration exits 0
- [ ] New endpoint appears in `src/shared/clients/MyApiClient.ts`
- [ ] TypeScript compiles cleanly after regeneration (`npm run build` exits 0)
- [ ] New method callable via `useApiClient()` or `usePublicApiClient()` as appropriate

### 4.3 Adding an EF Core migration

```bash
dotnet ef migrations add AddProductsTable \
  --project Sample.Infrastructure \
  --startup-project MyApp.Api
```

- [ ] Migration file generated in `Sample.Infrastructure/Migrations/`
- [ ] `Up()` and `Down()` methods present and plausible
- [ ] `dotnet run --project MyApp.AppHost` applies new migration via MigrationService
- [ ] `dotnet test` (integration) passes — `MigrateAsync()` applies the new migration in test fixture
- [ ] Rolling back: `dotnet ef database update <previous-migration>` works cleanly

### 4.4 Adding a new feature flag

Edit `config/featureflags.yaml` to add a new flag, e.g.:

```yaml
NewFeature:
  shared: false
  staging: true
  production: false
```

- [ ] `dotnet run config/gen-appsettings.cs -- --env staging --output ...` produces JSON with `NewFeature: true`
- [ ] `IFeatureManager.IsEnabledAsync("NewFeature")` returns `true` in Staging environment
- [ ] Frontend: `useFeatureFlags()` hook exposes the new flag value (if flags are exposed via API)
- [ ] Flag does not appear in committed files (generated appsettings gitignored)

### 4.5 Dev hydration script (requires Azure + Key Vault)

```bash
.\scripts\dev-hydrate.ps1
```

- [ ] Script authenticates via `az login` (prompts if not logged in)
- [ ] Reads secret names from `config/user-secrets.example.json`
- [ ] Pulls each value from the staging Key Vault
- [ ] Writes values to `dotnet user-secrets` for the AppHost project
- [ ] Writes values to `.env.local` for the frontend
- [ ] Running again (`--skip-existing`) doesn't overwrite locally overridden values
- [ ] `dotnet run --project MyApp.AppHost` works after hydration with real connection strings

### 4.6 Local development without Aspire

```bash
cd MyApp.Web
echo "VITE_API_BASE_URL=http://localhost:5000" > .env.local
npm run dev
```

- [ ] `WebProject.Web/README.md` documents this workflow clearly
- [ ] Vite dev server starts and proxies API calls to `VITE_API_BASE_URL`
- [ ] Dev login panel respects `VITE_DEV_LOGIN_ENABLED` (or falls back to `import.meta.env.DEV`)

---

## Suite 5 — Observability

### 5.1 Local structured logging

```bash
dotnet run --project MyApp.AppHost
```

- [ ] API console output shows `[HH:mm:ss INF] SourceContext: Message` format (Serilog template)
- [ ] No Seq sink configured; no Seq connection string references anywhere in source
- [ ] `Aspire.Hosting.Seq` NOT in `Directory.Packages.props`
- [ ] Aspire dashboard displays structured logs from the API (via OpenTelemetry OTLP)
- [ ] Aspire dashboard displays traces (request spans visible)

### 5.2 Health endpoints

- [ ] `GET /health` returns 200 in Development
- [ ] `GET /alive` returns 200 in Development
- [ ] `GET /health` returns 200 in Staging (not just Development)
- [ ] `GET /health` is not required to be publicly accessible in Production (acceptable to restrict, but should not break ACA/App Service health probes)

### 5.3 OpenTelemetry plumbing

Check `MyApp.ServiceDefaults/Extensions.cs`:

- [ ] `AddOpenTelemetry()` registered with traces, metrics, and logs
- [ ] OTLP exporter is configured (commented out or behind env var) — documents the path to Azure Monitor/Grafana/Datadog
- [ ] Aspire dashboard OTLP endpoint used for local dev

---

## Suite 6 — Auth Edge Cases

### 6.1 Token expiry and silent refresh

- [ ] Log in as any user; wait for access token to expire (or manually shorten token lifetime in development config)
- [ ] Next authenticated API call succeeds without user interaction (silent refresh via refresh token cookie)
- [ ] Refresh token rotation: old refresh token is invalidated after use

### 6.2 Dev login panel absent in production build

```bash
cd MyApp.Web
VITE_DEV_LOGIN_ENABLED=false npm run build
```

- [ ] Dev login panel component not present in production bundle (search built JS for `dev-login` or `admin@localhost`)
- [ ] API: resource owner password grant endpoint returns 400/404 when `DevLogin:Enabled` is false/absent in config

### 6.3 OpenIddict registration and discovery

```bash
curl http://localhost:5000/.well-known/openid-configuration
```

- [ ] Discovery document returns valid JSON
- [ ] `authorization_endpoint`, `token_endpoint`, `end_session_endpoint` present
- [ ] `code_challenge_methods_supported` includes `S256` (PKCE)

### 6.4 CORS correctness

- [ ] Frontend origin is not hardcoded; reads from Aspire service refs or `Cors:AllowedOrigins` config
- [ ] Browser devtools shows no CORS errors on API calls from frontend
- [ ] A request from an unauthorized origin returns a CORS error (not silently allowed)

---

## Suite 7 — Advanced / Optional Extension Scenarios

> These tests cover documented opt-in patterns from V2_GOALS. Each begins with a fresh scaffold.

### 7.1 Switching from SPA to SSR mode

```bash
dotnet new webproject -n MyApp -o MyApp
cd MyApp
# Edit MyApp.Web/vite.config.ts: remove `spa: { enabled: true }`
```

- [ ] `WebProject.Web/README.md` documents this process clearly
- [ ] `npm run dev` still starts after removing the SPA config
- [ ] `npm run build` exits 0 in SSR mode
- [ ] README notes that SWA is no longer viable for SSR; ACA/App Service/Docker required

### 7.2 Adding a social login provider

Follow the documented extension guidance in the auth README.

- [ ] Step-by-step guidance exists in the auth module or a README
- [ ] Adding Google OAuth: register middleware, add client ID/secret to user secrets, restart — login button appears
- [ ] Existing email/password login still works alongside social login

### 7.3 PostHog feature flags (opt-in)

```bash
# Set PostHog API key in user secrets
dotnet user-secrets set "PostHog:ApiKey" "phc_yourkey" --project MyApp.AppHost
```

- [ ] PostHog `IFeatureDefinitionProvider` activates when API key is present
- [ ] `IFeatureManager.IsEnabledAsync("ExampleFlag")` evaluates via PostHog (verify in logs)
- [ ] When API key is absent, `IFeatureManager` falls back to appsettings flags — no error thrown
- [ ] Frontend: PostHog JS SDK initializes when `VITE_POSTHOG_KEY` is set in `.env.local`; analytics events fire

### 7.4 Azure App Configuration as opt-in

- [ ] Adding `AddAzureAppConfiguration()` manually to `Program.cs` works alongside the generated appsettings
- [ ] Sentinel-based dynamic refresh functions when Azure App Configuration is manually wired up
- [ ] Template does NOT require or provision Azure App Configuration by default

### 7.5 Multi-role RBAC extension

- [ ] Add a new `Manager` role to the seeder and `AppRole` definitions
- [ ] Protect an endpoint with `[Authorize(Roles = "Manager,Admin")]`
- [ ] Seed a `manager@localhost` account with the Manager role
- [ ] Dev login panel updated to show the new account button
- [ ] Fitness tests don't block the new role addition

---

## Suite 8 — Template Packaging and Distribution

> Tests the template itself as a redistributable artifact.

### 8.1 Install from NuGet package

```bash
# Pack the template
cd .. # back to DotnetTemplates root
dotnet pack Module/  # (or however the .nupkg is produced)
dotnet new install ./path/to/package.nupkg

# Scaffold from installed package
dotnet new webproject -n MyApp -o MyApp
```

- [ ] Template installs cleanly
- [ ] Scaffold produces the same output as installing from source

### 8.2 Scaffold with all option combinations

```bash
# 1. No options (default)
dotnet new webproject -n App1 -o App1

# 2. App Service only
dotnet new webproject -n App2 -o App2 --UseAzureAppServiceInfra --AzureResourcePrefix app2

# 3. ACA only
dotnet new webproject -n App3 -o App3 --UseAzureContainerInfra --AzureResourcePrefix app3
```

- [ ] All three scaffolds build cleanly (`dotnet build` exits 0)
- [ ] Option 1: no infra or workflow files
- [ ] Option 2: App Service workflows and Bicep only; no ACA files
- [ ] Option 3: ACA workflows, Bicep, and `Dockerfile`; no App Service files
- [ ] Options 2 and 3 are mutually exclusive — if both flags are passed, document the expected behavior

### 8.3 Source rename correctness

```bash
dotnet new webproject -n AcmeCorp -o AcmeCorp --UseAzureContainerInfra --AzureResourcePrefix acme
```

- [ ] `WebProject` renamed to `AcmeCorp` everywhere: project files, namespaces, solution, Aspire resource names
- [ ] `webprojectazureprefix` replaced with `acme` everywhere: Bicep, workflow files, infra scripts
- [ ] `Sample.*` projects are NOT renamed (they are domain sample modules, not template infrastructure)
- [ ] No residual `WebProject` strings in any non-sample file (`grep -r "WebProject" . --include="*.cs" --include="*.bicep" --include="*.yml"`)

### 8.4 Gitignore completeness

- [ ] `appsettings.Staging.json` is gitignored
- [ ] `appsettings.Production.json` is gitignored
- [ ] `appsettings.local.json` is gitignored
- [ ] `.env.local` is gitignored
- [ ] `node_modules/` is gitignored
- [ ] `bin/` and `obj/` are gitignored
- [ ] No secrets or generated artefacts appear in `git status` after a fresh scaffold + dev-setup run

---

## Regression Checklist (run after any significant change)

Quick smoke test covering the most breakage-prone areas:

- [ ] `dotnet new webproject -n Smoke -o Smoke` exits 0
- [ ] `dotnet build Smoke/Smoke.slnx` exits 0 with 0 errors
- [ ] `dotnet test Smoke/Smoke.slnx --filter "FullyQualifiedName!~Integration"` — all pass
- [ ] `dotnet run --project Smoke/Smoke.AppHost` — all services healthy within 60 seconds
- [ ] Browser: frontend loads, feature flags page works, dev login works
- [ ] `dotnet new webproject -n SmokeAca -o SmokeAca --UseAzureContainerInfra --AzureResourcePrefix smoke` exits 0
- [ ] `docker build -f SmokeAca/SmokeAca.Api/Dockerfile -t smoke-api:test SmokeAca/` exits 0
- [ ] `grep -r "sync-appconfig" SmokeAca/` → 0 matches

---

*Last updated: 2026-05-15*
