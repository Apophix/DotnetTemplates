# v2 Goals

This document describes the scope, rationale, open questions, and known concerns for the v2
rewrite of the template. Nothing here is final — treat it as a working brief to refine before
implementation begins.

---

## 1. Frontend Overhaul

### What changes

- **Remove all demo/scaffold content** — every file under `src/routes/demo/`, the
  `src/data/demo.punk-songs.ts` stub, the TanStack Start boilerplate `index.tsx`, the
  `Header.tsx` nav (which only serves the demos), and `todos.json`.
- **Stay in SPA mode (client-only, static files).** The current `vite.config.ts` setting
  `tanstackStart({ spa: { enabled: true } })` is correct and remains unchanged. The template
  ships as a fully static SPA deployable to SWA or any CDN with no Node server required.
- **Produce a clean, minimal starting point.** A single `__root.tsx`, a neutral landing/index
  route, and the feature-flags demo page (it demonstrates a real backend integration and is worth
  keeping as a reference).
- **New `README.md` for `WebProject.Web`** — see section below.
- **Regenerate `src/lib/clients/MyApiClient.ts`** once the v2 frontend cleanup is complete.
  Demo backend endpoints are kept (decision 2), so the generated client will include them.

### New `WebProject.Web` README

Should cover:

- How the Aspire + Vite integration works and what `VITE_API_BASE_URL` does
- **Rendering mode guidance** (the main reason for the new README):
  - **SPA mode (default)** — client-only, static files; no Node server required. Deployable to
    SWA, S3, any CDN. Best for authenticated dashboards, internal tools, and any app where SEO
    is not a concern. This is the template default — `spa: { enabled: true }` in `vite.config.ts`.
  - **SSR** — enables server-side rendering for SEO-critical pages (marketing sites, landing
    pages, public content). Requires a Node server process; SWA is no longer viable (use ACA,
    App Service, or Docker). Enable by removing `spa: { enabled: true }` from `vite.config.ts`.
    Per-route `ssr: false` can opt individual routes back to client rendering within an SSR app.
  - **Data-only SSR** (`ssr: 'data-only'` per route) — loader runs server-side, component
    renders client-side; useful middle ground when only data fetching needs to be server-side.
  - **SSG** — TanStack Start doesn't have first-class SSG yet; note alternatives if relevant.
- When to add `@tanstack/react-start` and `@tanstack/react-router-ssr-query` (not needed in
  SPA mode — only required if switching to SSR).
- API client regeneration (`npx apx-gen`).
- Local dev without Aspire (`VITE_API_BASE_URL` in `.env.local`).

### Resolved / notes

- **SSR changes the hosting story.** ✅ Not a concern for the default — the template ships as
  SPA (static files). SWA is the natural default frontend host. The README documents that
  switching to SSR requires a Node server and a different hosting option (ACA, App Service,
  or Docker); the infra READMEs reinforce this.

- **Does SSR interact with the API client?** ✅ Generally no. SSR in this template is a
  rendering optimisation; API interactions happen on the client. Individual routes can choose to
  call the API in their loaders for data-driven SSR if needed, but that is a per-project
  decision. The default client (`MyApiClient`) is fine as-is.

- **Keep or remove the demo endpoints from the backend?** ✅ Keep them if they remain useful as
  reference patterns for future development (`GetCheckoutVariantEndpoint`, `SampleUnionEndpoint`,
  `GetFeatureFlagsEndpoint`). Mark them clearly as sample/demo code. Do not remove.

- **The index page.** ✅ A "your project starts here" landing page that also demonstrates feature
  flags. Gives new developers an immediately working reference without being a blank void.

- **`@tanstack/react-devtools` is in `dependencies`, not `devDependencies`.** ✅ Wrap the
  devtools render in `import.meta.env.DEV` so they are tree-shaken from production builds.
  Leave the package in `dependencies` (Vite handles the elimination).

---

## 2. CI/CD and Staging Workflow

### New staging model: trunk-based integration environment

Replace the current PR-per-slot model with a single shared staging environment that always
reflects **main merged with all currently open PRs**. Conceptually:

```
staging = merge(main, PR-1, PR-2, PR-3, ...)
```

Workflow triggers: PR opened, synchronised, closed, or main updated.

**Steps:**
1. Checkout `main`.
2. For each open PR, attempt `git merge --no-commit --no-ff` in chronological (oldest-first)
   order. If a conflict is detected, post a status check failure on that PR, skip it, and
   continue with the rest.
3. Check for EF migration conflicts in the merged tree (see below).
4. Build and deploy the merged result to the shared staging environment.
5. Post a summary comment on each open PR: ✅ included in staging / ⚠️ skipped (conflict).

**EF migration conflict detection.** No static file analysis needed. After the git merge
succeeds, the pipeline runs `dotnet ef database update` against the staging database as a
deployment step. If it fails for any reason — incompatible schema, duplicate migration name,
invalid SQL — the pipeline posts a status check failure on all PRs involved in the merge and
halts deployment. The error output is included in the PR comment so the developer knows exactly
what went wrong. This catches both file-level and logical schema conflicts at the cost of
requiring an actual database apply attempt.

**Staging database.** Because migrations are applied against a live database and failures can
leave it in a partially-migrated state, the nightly wipe-and-rebuild pipeline (see below) is
the recovery mechanism. There is no need for a manual rollback procedure in normal operation —
the nightly reset restores a clean baseline. If a migration failure blocks staging for an
entire day, the database can be manually wiped ahead of the nightly run.

### Nightly staging wipe-and-rebuild

A scheduled pipeline runs nightly (e.g., 02:00 UTC) and performs a full reset of the staging
environment:

1. Drop and recreate the staging database (or restore from a clean schema snapshot).
2. Run all migrations from scratch against the fresh database.
3. Run the dev seeder (`Common.Library.DevSeeder`) to repopulate reference/seed data.
4. Redeploy the current staging build (no new merge — uses whatever was last deployed).

**Why this matters:**
- Migrations that are applied but whose PR is later closed or modified can leave orphaned schema
  changes in the staging database. The nightly reset eliminates drift without anyone needing to
  track it.
- It also means the migration apply step during staging deployment is not the only safeguard —
  if a bad migration slips through, the next nightly reset will surface it cleanly.
- Seed data is always fresh, which prevents test pollution from accumulating across many PR
  deployments throughout the day.

The nightly job posts a summary (pass/fail, migration list applied, seed row counts) as a
GitHub Actions job summary for visibility.

### What this replaces

- Per-PR App Service slots and per-PR databases are gone.
- `pr.yml` and `pr.aca.yml` are replaced by a single `staging.yml` workflow.
- The `deploy.yml` main-branch pipeline stays for production promotion, simplified.

### Resolved / notes

- **Merge order matters.** ✅ Chronological order. The team owns conflict resolution — if an
  older PR is blocking others it should be fixed or updated promptly. When a PR is skipped due
  to a conflict, the pipeline runs the EF "down" migration for any of that PR's migrations that
  were already applied, leaving the database clean for the remaining PRs. If a down migration
  itself fails or the database ends up in an unrecoverable state, there is an on-demand
  "nuke and rebuild" trigger on the staging pipeline (same steps as the nightly wipe).

- **What happens after a conflict is resolved?** ✅ Any push to an open PR re-triggers the
  staging rebuild, which picks up the now-resolved PR. No debounce baked in — can be added
  later if noisy push patterns become a problem, but the team's PR cadence doesn't warrant it
  upfront.

- **Staging is now a shared environment.** ✅ Acknowledged and accepted. This is already the
  team's de-facto model (manual merges into a dedicated `stage` branch) — this workflow just
  automates and self-heals that process. Developers continue to treat staging as shared.

- **Migration service on production.** ✅ The API deployment step must not begin until the
  migration service has exited successfully. In CI this means the migration job is a required
  predecessor to the API deploy step (GitHub Actions `needs:` dependency). The deploy pipeline
  will be structured as: `build → migrate → deploy-api`, where `deploy-api` only runs if
  `migrate` succeeds.

- **Production promotion.** ✅ Build and deploy from `main` directly. The staging build is
  ephemeral (merged-PR composite) and is never promoted.

---

## 3. Infrastructure — Modular Options

### Goals

- **No upfront infrastructure choice.** All options ship as separate, self-contained folders
  under `infra/`. A developer picks (or combines) options at project launch time rather than
  at template instantiation time.
- **Minimal, readable Bicep.** Prefer flat module files over deep nesting. Each option's
  `README.md` explains what it provisions, what parameters are required, and how to bootstrap.
- **Mix-and-match is explicit and documented.** Common combinations get their own guidance
  (e.g., "ACA API + SWA frontend + managed PostgreSQL").

### Proposed folder structure

```
infra/
  azure-app-service/          # App Service + SWA + Azure SQL (current main.bicep baseline)
    main.bicep
    main.bicepparam
    README.md

  azure-container-apps/       # ACA + SWA + Azure SQL (current main.aca.bicep baseline)
    main.bicep
    main.bicepparam
    README.md

  containers-generic/         # Docker Compose + Dockerfile(s) — no Azure dependency
    docker-compose.yml
    docker-compose.prod.yml
    README.md

  modules/                    # Shared Bicep modules reused across Azure options
    keyvault.bicep
    managed-identity.bicep
    sql-server.bicep
    sql-database.bicep
    static-web-app.bicep
    app-service.bicep
    aca-environment.bicep
    aca-app.bicep
    container-registry.bicep
    storage.bicep
```

Each `README.md` should cover: what's provisioned, prerequisites, `az stack` deploy command,
and how to wire it up to the CI/CD workflows.

### Current infra vs. v2 target

The existing `infra/` folder already has most of the Bicep modules — the work is primarily
reorganisation and removing the `app-configuration.bicep` module (dropped dependency, see
section 4). The ACA-variant files (`main.aca.bicep`, `main.aca.bicepparam`) become the
`azure-container-apps/` option.

### Hosting note

The template defaults to SPA mode (static files). SWA is the natural frontend host for all
Azure options. If a project later enables SSR, the frontend requires a Node server process and
SWA is no longer viable. The README documents the switch; the infra READMEs note which options
support an SSR frontend:

| Infra option          | SPA (default) | SSR (opt-in) |
|---|---|---|
| App Service + SWA     | ✅            | ❌ Use App Service for the Node server instead |
| ACA + SWA             | ✅            | ❌ Add a second ACA app for the Node server |
| ACA + ACA             | ✅            | ✅ |
| Generic containers    | ✅            | ✅ |

### Resolved / notes

- **PostgreSQL vs SQL Server.** ✅ Default to SQL Server for Azure options. Azure Managed SQL
  Server on the lowest tier is cost-competitive with managed PostgreSQL. The Aspire local dev
  setup (currently PostgreSQL) will be updated to use SQL Server via the Aspire SQL Server
  hosting package so local and cloud environments use the same engine. The `postgresql.bicep`
  module in the proposed folder layout is dropped; SQL Server modules stay.

- **`az stack` vs. `az deployment`.** ✅ Keep `az stack` but change `--action-on-unmanage` from
  `deleteAll` to `detachAll`. Resources removed from the Bicep template are detached from the
  stack rather than deleted, preventing accidental destruction. Additionally, critical resources
  (databases, Key Vault, storage) will have Azure resource locks (`CanNotDelete`) applied via
  Bicep — removing a resource requires manually deleting the lock first, adding a deliberate
  friction layer before any destructive action.

- **Generic containers option scope.** ✅ Ship a `docker-compose.yml` and a clear README.
  Keep it simple — no Kubernetes, no platform-specific config. The README notes that the same
  images work on any container platform.

- **The bootstrap script.** ✅ Keep at `infra/` root (shared across Azure options, not needed
  for `containers-generic/`). Prioritise thorough documentation over restructuring — a clear
  step-by-step README is more valuable than moving the file.

---

## 4. Configuration — Drop Azure App Configuration

### Goal

Maintain config-as-code (the `config/appconfig.yaml` + `config/featureflags.yaml` pattern is
good and should be kept) but target a simpler delivery mechanism that doesn't require an Azure
App Configuration resource.

### Proposed approach

**Non-secret config values** are delivered as generated, gitignored appsettings files
(`appsettings.Staging.json`, `appsettings.Production.json`). The `config/` YAML files are the
committed source of truth; the appsettings JSON is regenerated by a CI script at deploy time
and applied to the target infrastructure. `appsettings.local.json` (also gitignored) is the
local dev override file.

**Secrets** continue to live in Azure Key Vault and are referenced from app settings via Key
Vault reference syntax (`@Microsoft.KeyVault(...)` for App Service, or mounted as environment
variables for ACA). The Key Vault itself is still provisioned by Bicep.

**Feature flags** without Azure App Config lose dynamic refresh (no sentinel-based reload). The
trade-off is simplicity — flags are set at deploy time and a redeploy/restart is required to
change them. For most projects this is acceptable; the README should call it out explicitly.
The `Microsoft.FeatureManagement` package stays (it reads from `IConfiguration` which works
with appsettings), and `AddAzureAppConfigurationDefaults()` / `AppConfigurationExtensions.cs`
are removed entirely.

**Dynamic flag refresh as an opt-in** — if a project genuinely needs runtime flag toggling
without redeployment, PostHog feature flags (section 5) are the recommended path. Document
the migration path from the static appsettings approach to PostHog flags.

### What changes

- Remove `AppConfigurationExtensions.cs` from `Common.Library.Api`.
- Remove `Azure.Identity`, `Microsoft.Azure.AppConfiguration.AspNetCore`, and
  `Microsoft.Extensions.Configuration.AzureAppConfiguration` from `WebProject.Api`.
- Remove `app-configuration.bicep` from `infra/modules/`.
- Replace `config/sync-appconfig.sh` and `config/sync-appconfig.aca.sh` with a script that
  generates environment-specific appsettings JSON from the YAML source and applies it to the
  target infrastructure (Bicep params or `az webapp/containerapp config` calls).
- `appsettings.Staging.json` and `appsettings.Production.json` become generated artefacts
  (gitignored). `appsettings.local.json` (also gitignored) replaces `appsettings.Development.json`
  as the local dev override file.

### Resolved / notes

- **Committed appsettings vs. generated.** ✅ Generated appsettings are gitignored — the
  config YAML is the committed source of truth and appsettings JSON is a build/CI artefact.
  `appsettings.local.json` (gitignored) is the local dev override file; developers manage their
  own local values there and do not need visibility into staging config unless actively debugging
  against that environment. Config diffs are reviewed at the YAML level, not the generated JSON
  level.

- **Cross-service shared config.** ✅ The CaC → IaC pipeline handles distribution; generated
  config may be duplicated across services and that is acceptable since it's generated. Azure
  App Configuration (and similar centralised config services) will remain a **supported opt-in**
  — the template simply won't require or provision it by default. Teams that need dynamic
  refresh, centralised multi-service config, or a portal UI for config management can add it
  without fighting the template.

- **`SLOT_NAME` / PR slot override labels.** ✅ Removed — these were artefacts of the per-PR
  App Service slot model, which is gone in v2.

---

## 5. Observability — Drop Seq, Add PostHog / Local-Only

### Local-only (default)

The `Serilog → Console` sink already works perfectly for local dev. The Aspire dashboard
provides traces, metrics, and structured logs via OpenTelemetry without any external service.
"Local-only" simply means: remove Seq from the Aspire AppHost, keep the console sink, keep the
OpenTelemetry plumbing in `ServiceDefaults`.

Changes:
- Remove `Aspire.Hosting.Seq` from `Directory.Packages.props`.
- Remove the Seq container + `IsPortInUse()` hack from `AppHost.cs`.
- Remove `Serilog.Sinks.Seq` from `Common.Library.Logging`.
- Remove Seq connection string logic from `LoggingExtensions.cs`.
- The Aspire dashboard continues to be the primary observability tool for local dev.

### PostHog (opt-in)

PostHog is a product analytics and feature flag platform that also supports event capture, session
recordings, and A/B testing. It is **not** a structured log aggregator (Seq replacement for
server logs) — this distinction matters.

**What PostHog covers:**
- Frontend: analytics events, session recording, feature flags, A/B tests (JS SDK, React hooks).
- Backend: feature flag evaluation, server-side event capture (.NET SDK exists).

**What PostHog does not cover:**
- Structured server logs (exceptions, request logs, trace data). The console sink + OpenTelemetry
  remains the answer for these. In production, teams should route OTLP telemetry to their
  preferred backend (Azure Monitor, Grafana, Datadog, etc.) — this is already uncommented in
  `ServiceDefaults` and should just be documented.

**PostHog feature flags vs. appsettings flags.** When PostHog is configured, a PostHog-backed
`IFeatureDefinitionProvider` is registered, and `IFeatureManager` evaluates flags via PostHog.
When PostHog is not configured, `IFeatureManager` falls back to the appsettings source
automatically — no code changes required. Backend code always depends only on `IFeatureManager`,
never directly on PostHog.

**Setup experience goal:** "PostHog in 5 minutes." A developer should be able to:
1. Create a PostHog cloud project, copy the API key.
2. Set the key in user secrets (backend) and `.env.local` (frontend).
3. Run `dotnet run` — PostHog is wired up.

The template ships with PostHog fully integrated but all calls behind a null-check on whether
the API key is configured. If the key is absent, PostHog is silently skipped (no errors, no
missing DI registrations).

### Resolved / notes

- **Self-hosted PostHog.** ✅ Cloud-hosted only. No Aspire container, no self-host support.
  The cloud free tier is generous enough for most projects.

- **Production structured logs.** ✅ PostHog + OpenTelemetry is the observability stack.
  PostHog handles events, analytics, and feature flags. OTLP telemetry (traces, metrics,
  structured logs) is exported via the existing `ServiceDefaults` OpenTelemetry plumbing —
  the destination (Azure Monitor, Grafana, Datadog, etc.) is a per-project infrastructure
  choice and does not need to be prescribed by the template. The Aspire dashboard covers
  everything locally.

- **PostHog feature flags and `IFeatureManager` on the backend.** ✅ Implement a PostHog-backed
  `IFeatureDefinitionProvider` using the PostHog .NET SDK. `IFeatureManager` remains the
  injection point throughout the application — backend code never takes a direct dependency on
  PostHog. When PostHog is not configured, the provider falls back to the existing appsettings
  source so the template works out of the box without a PostHog key.

---

## 6. Local Development — "Pull Once, Hydrate Locally"

### Current state

`scripts/dev-setup.ps1` already does most of this:
- Checks prerequisites (dotnet, node, docker).
- Restores packages.
- Creates `.env.local` from `.env.example`.
- Checks which user secrets are defined in `config/user-secrets.example.json` and reports
  missing ones — but does **not** pull values from Key Vault.

### v2 goal

Add an optional `--hydrate` flag (or a separate `dev-hydrate.ps1`) that:
1. Authenticates to Azure with the developer's own identity (`az login`).
2. Reads the required secret names from `config/user-secrets.example.json`.
3. Pulls each value from the staging Key Vault.
4. Writes them to `dotnet user-secrets` (AppHost project) and `.env.local` (frontend).

This preserves the existing "no Azure required" default while making the "connect to real staging
secrets" workflow a one-command operation. After hydration, the developer never touches Azure
again for the normal dev loop.

### Resolved / notes

- **Key Vault access for developers.** ✅ Grant `Key Vault Secrets User` to an Entra group
  (e.g., "Developers") rather than per-user. Documented as a one-time onboarding step in the
  project README — a new team member joins the group and the hydrate script works immediately.

- **Secret rotation.** ✅ The hydrate script overwrites existing values by default. Pass
  `--skip-existing` to preserve any locally overridden values and only pull secrets that aren't
  already set.

- **PostHog API key as a secret.** ✅ Out of scope for the template's hydrate script. Each
  project documents PostHog setup as part of its developer onboarding guide.

---

## 7. Authentication and RBAC — OpenIddict

### Goal

Ship a complete, working auth layer out of the box. No third-party identity provider required.
A developer cloning the template should have login, logout, role-based access, and protected
routes working immediately, with seeded test accounts for every role.

### Stack

**[OpenIddict](https://documentation.openiddict.com/)** as the OAuth 2.0 / OpenID Connect
server, hosted in `WebProject.Api` via a dedicated auth module (`Common.Library.Auth` or
similar). OpenIddict stores grants and applications in the existing SQL Server database via its
EF Core integration. No separate identity database.

**ASP.NET Core Identity** as the user/role store, also backed by the same database.

**Frontend** uses the PKCE authorization code flow. TanStack Router guards routes based on the
presence of a valid token / decoded role claims. No third-party auth library required on the
frontend — the OpenIddict token endpoint and standard OIDC endpoints are sufficient.

### RBAC model

Ship a minimal, extensible set of roles out of the box:

| Role | Description |
|---|---|
| `Admin` | Full access |
| `User` | Standard authenticated user |

Projects can add roles as needed. The seeder creates at least one account per role. Role checks
on the API use `[Authorize(Roles = "...")]` or FastEndpoints' `Roles()` policy builder.

### Seeded development accounts

`Common.Library.DevSeeder` seeds the following accounts in Development and Staging
environments (never Production):

| Email | Password | Role |
|---|---|---|
| `admin@dev.local` | `Dev@dmin1!` | Admin |
| `user@dev.local` | `Dev@User1!` | User |

Passwords follow ASP.NET Identity's default complexity rules. They are hardcoded in the seeder
(not secrets) since they exist solely in non-production environments.

### One-click dev login

In Development and Staging, the frontend renders a "Dev Login" panel (conditionally on
`import.meta.env.DEV` or an `VITE_DEV_LOGIN_ENABLED=true` env var for staging). The panel
displays one button per seeded account. Clicking a button:

1. POSTs to the token endpoint with the account's credentials (resource owner password grant,
   enabled only in non-production).
2. Stores the access token in memory; the refresh token is set as an `HttpOnly` cookie by the
   server. Silent refresh handles subsequent token renewals transparently.
3. Redirects to the authenticated home page.

This entirely replaces the current `DevAuthMiddleware` / `DevBypass` approach, which bypassed
auth rather than providing real auth. The new approach means staging runs real authentication,
eliminating the `appsettings.Staging.json` `DevBypass.Enabled: true` security issue.

**The dev login panel must not render in production.** Gate it on both `VITE_DEV_LOGIN_ENABLED`
(frontend) and a corresponding backend setting that enables the resource owner password grant.
Both must be absent / false for the production build.

### OpenIddict configuration

| Setting | Development / Staging | Production |
|---|---|---|
| Resource owner password grant | ✅ enabled (powers dev login) | ❌ disabled |
| Authorization code + PKCE | ✅ | ✅ |
| Token encryption | ✅ (dev cert) | ✅ (Key Vault cert) |
| HTTPS requirement | relaxed (Aspire handles) | enforced |

Token signing and encryption certificates live in Key Vault for staging and production. Local
dev uses OpenIddict's development certificate (auto-generated, not a secret).

### Resolved / notes

- **Separate Identity project or co-located in the API?** ✅ Auth logic lives in its own
  module(s) (`Common.Library.Auth` or similar) but is hosted within `WebProject.Api` by
  default. This keeps the deployment simple while keeping the code cleanly separated. If a
  project needs to deploy the identity server independently, the module boundary makes
  extraction straightforward.

- **Social login / external providers.** ✅ Nothing shipped by default. The README documents
  social login as a first-class extension point with step-by-step guidance for adding a
  provider (Google, Microsoft, GitHub) via ASP.NET Core external auth middleware + OpenIddict.
  The goal is that adding a provider feels like following a short checklist, not reverse-
  engineering the auth setup.

- **Token storage on the frontend.** ✅ In-memory access token + `HttpOnly` refresh token
  cookie. Silent refresh handles page reloads and new tabs transparently. This is the most
  secure practical option and will be the implemented default.

- **`useApiClient()` hook and auth headers.** ✅ `useApiClient()` injects the `Authorization:
  Bearer` header from the in-memory token. A separate `usePublicApiClient()` (or
  `createAnonymousApiClient()`) is provided for unauthenticated endpoints — public API calls
  never accidentally carry a token, and the distinction is explicit in code.

- **Aspire and the identity server.** ✅ Should be fine given both live in the same process.
  Will address if any service discovery edge cases arise during implementation.

- **Staging dev login accounts.** ✅ No restrictions needed. Staging contains no sensitive
  data by design, so open access to the dev login panel is acceptable.

---

## 8. Audit Items to Address in v2

Several findings from `AUDIT.md` become free fixes in the context of v2 changes:

| Item | Resolution |
|---|---|
| `appsettings.Staging.json` has `DevBypass.Enabled: true` | Eliminated — replaced by real OpenIddict auth + dev login panel (section 7) |
| `DevAuthMiddleware` bypasses auth rather than providing it | Replaced by OpenIddict resource owner password grant + dev login panel |
| CORS hardcodes `localhost:3000` for all environments | Fix during API cleanup |
| Health endpoints only in `IsDevelopment()` — breaks CI smoke tests | Fix in `ServiceDefaults`; expose in Staging behind auth or just expose `/health` unconditionally |
| `AppHost.cs` double `.WaitFor(database)` | Fix during AppHost cleanup |
| Instructions reference wrong paths (`src/shared/` vs `src/lib/`) | Fix in `frontend.instructions.md` and `copilot-instructions.md` |
| `useApiClient()` hook doesn't exist | ✅ Create `useApiClient()` (authenticated) + `usePublicApiClient()` (anonymous); auth header injected centrally |
| `SampleItem.CreatedAt` uses `DateTime` not `DateTimeOffset` | Fix during entity cleanup |
| `DatabaseFixture` uses `EnsureCreatedAsync` not `MigrateAsync` | Fix |
| `todos.json` in working tree | Delete |
| `@tanstack/react-devtools` in `dependencies` not `devDependencies` | Fix during package.json cleanup |

Items that need attention during implementation:

- **EF Core version** — bump to EF Core 10 or document the intentional pin at 9.

---

## Summary of Open Decisions

| # | Question | Decision / Status |
|---|---|---|
| 1 | SSR vs SPA as the default, and impact on hosting options | ✅ SPA default (static files); SSR documented as opt-in for SEO scenarios |
| 2 | Backend demo endpoints — keep or remove? | ✅ Keep; mark as sample/demo code |
| 3 | Config delivery: committed appsettings JSON vs. generated at CI time | ✅ Generated and gitignored; YAML is source of truth; `appsettings.local.json` for local dev |
| 4 | PostHog flags on backend via `IFeatureManager` or appsettings-only backend flags | ✅ PostHog-backed `IFeatureDefinitionProvider`; `IFeatureManager` stays as the injection point; falls back to appsettings if PostHog not configured |
| 5 | Production structured log recommendation (Azure Monitor, leave as opt-in, or something else) | ✅ PostHog + OTLP; OTLP destination is a per-project infra choice, not prescribed by the template |
| 6 | DB engine for Azure infra options — PostgreSQL to match local dev, or SQL Server | ✅ SQL Server; update Aspire local dev to match |
| 7 | `az stack` vs `az deployment` for infra workflow | ✅ Keep `az stack`; `detachAll` + resource locks on critical resources |
| 8 | `useApiClient()` hook — create it to match instructions, or update instructions | ✅ Create it; becomes the auth header injection point |
| 9 | Staging merge conflict resolution ordering (chronological, labelled priority?) | ✅ Chronological; team responsible for resolving blocking PRs promptly |
| 10 | Self-hosted PostHog container in Aspire for fully offline dev | ✅ Cloud-hosted only; no self-host support |
| 11 | OpenIddict co-located in API vs. dedicated Identity project | ✅ Separate module(s), co-located in `WebProject.Api`; document extraction path |
| 12 | Frontend token storage strategy (in-memory + silent refresh vs. sessionStorage vs. localStorage) | ✅ In-memory access token + `HttpOnly` refresh token cookie with silent refresh |
| 13 | Dev login panel in staging: open or IP/header restricted? | ✅ Open — staging contains no sensitive data |
