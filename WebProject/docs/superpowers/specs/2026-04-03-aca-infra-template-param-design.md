# Design: Azure Container Apps Infrastructure Template Parameter

**Date:** 2026-04-03  
**Template:** `DotnetTemplates/WebProject`  
**Source:** Backported from MacroFoundry ACA infrastructure

---

## Summary

Add a `UseAzureContainerInfra` template parameter to the WebProject .NET template that scaffolds Azure Container Apps (ACA)-based infrastructure as an alternative to the existing `UseAzureAppServiceInfra` parameter. The two parameters are mutually exclusive. When neither is set, no infrastructure files are generated (existing behavior).

---

## New Template Parameter

```json
"UseAzureContainerInfra": {
  "type": "parameter",
  "datatype": "bool",
  "description": "Include Azure Container Apps infrastructure (Bicep IaC, GitHub Actions CI/CD, config sync scripts, bootstrap scripts).",
  "defaultValue": "false"
}
```

`AzureResourcePrefix` already exists and applies to both infra flavors.

---

## Architecture (ACA flavor)

```
Subscription
└── rg-<prefix>
    ├── id-<prefix>                        Managed identity
    ├── sql-<prefix>                       SQL logical server
    │   ├── sqldb-<prefix>-prod            Production database
    │   └── sqldb-<prefix>-stg             Staging database
    ├── kv-<prefix>-prod-<suffix>          Key Vault — production secrets only
    ├── kv-<prefix>-stg-<suffix>           Key Vault — staging + ephemeral PR secrets
    ├── st<prefix><suffix>                 Storage account
    ├── appconfig-<prefix>-<suffix>        App Configuration — staging store (shared/staging/PR labels)
    ├── appconfig-<prefix>-prod-<suffix>   App Configuration — production store (production label only)
    ├── cr<prefix>                         Container Registry (Basic SKU)
    ├── env-<prefix>-prod                  ACA Managed Environment (production)
    │   └── app-<prefix>-api               Container App (prod, multiple-revision mode)
    ├── env-<prefix>-stg                   ACA Managed Environment (staging)
    │   └── app-<prefix>-api-stg           Container App (staging, single-revision, min 0 replicas)
    └── swa-<prefix>                       Static Web App (React SPA)
```

**Key difference from App Service flavor:** Two App Configuration stores instead of one — the production store is isolated from all staging/CI writes. The `sync-appconfig.sh` script resolves the correct store by its `environment` tag.

**App Service flavor reference (unchanged):**

```
rg-<prefix>
├── appconfig-<prefix>-<suffix>   Single App Configuration store
├── asp-<prefix>                  App Service Plan (Standard S1+)
│   └── app-<prefix>-api          .NET 10 API
│       └── /slots/staging        Staging slot
└── swa-<prefix>                  Static Web App
```

---

## File Changes

### Files added to template source tree

#### ACA-only, no rename needed (conditionally included when `UseAzureContainerInfra`)

| File | Notes |
|---|---|
| `infra/modules/aca-app.bicep` | Container App resource + ingress/secrets/env/probes |
| `infra/modules/aca-environment.bicep` | ACA Managed Environment + Log Analytics workspace |
| `infra/modules/container-registry.bicep` | ACR (Basic SKU) + AcrPush + AcrPull role assignments |
| `infra/bootstrap.ps1` | One-time setup: registers providers, deploys initial stack, sets GitHub secret |
| `infra/bootstrap.sh` | Same as above for Linux/macOS |
| `.github/workflows/infra.yml` | Auto-deploys bicep stack on `infra/**` changes to main |
| `WebProject.Api/Dockerfile` | Multi-stage build: sdk:10.0 → aspnet:10.0, port 8080 |

#### Files that differ between flavors — stored with `.aca.` infix, renamed at instantiation

| Template source | Output path (when ACA) |
|---|---|
| `infra/main.aca.bicep` | `infra/main.bicep` |
| `infra/main.aca.bicepparam` | `infra/main.bicepparam` |
| `infra/deploy.aca.ps1` | `infra/deploy.ps1` |
| `infra/deploy.aca.sh` | `infra/deploy.sh` |
| `infra/README.aca.md` | `infra/README.md` |
| `.github/workflows/deploy.aca.yml` | `.github/workflows/deploy.yml` |
| `.github/workflows/pr.aca.yml` | `.github/workflows/pr.yml` |
| `config/sync-appconfig.aca.sh` | `config/sync-appconfig.sh` |

### Files modified

- `.template.config/template.json` — new parameter, new condition modifiers, rename mapping

### Files unchanged

- `config/appconfig.yaml` — identical content for both flavors
- `config/featureflags.yaml` — identical content for both flavors
- `infra/bicepconfig.json` — compatible with both flavors
- `infra/modules/managed-identity.bicep` — shared
- `infra/modules/sql-server.bicep` — shared
- `infra/modules/sql-database.bicep` — shared
- `infra/modules/keyvault.bicep` — shared
- `infra/modules/storage.bicep` — shared
- `infra/modules/static-web-app.bicep` — shared

---

## template.json Changes

### New parameter

```json
"UseAzureContainerInfra": {
  "type": "parameter",
  "datatype": "bool",
  "description": "Include Azure Container Apps infrastructure (Bicep IaC, GitHub Actions CI/CD, config sync scripts, bootstrap scripts).",
  "defaultValue": "false"
}
```

### Rename mapping (added to `sources[0]`)

```json
"rename": {
  "infra/main.aca.bicep": "infra/main.bicep",
  "infra/main.aca.bicepparam": "infra/main.bicepparam",
  "infra/deploy.aca.ps1": "infra/deploy.ps1",
  "infra/deploy.aca.sh": "infra/deploy.sh",
  "infra/README.aca.md": "infra/README.md",
  ".github/workflows/deploy.aca.yml": ".github/workflows/deploy.yml",
  ".github/workflows/pr.aca.yml": ".github/workflows/pr.yml",
  "config/sync-appconfig.aca.sh": "config/sync-appconfig.sh"
}
```

Rename entries for excluded files are no-ops — safe to declare globally.

### Condition modifiers (replace existing single modifier)

**Modifier 1 — Neither flavor selected (existing behavior, updated condition):**
```json
{
  "condition": "(!UseAzureAppServiceInfra && !UseAzureContainerInfra)",
  "exclude": [
    ".github/workflows/**",
    "infra/**",
    "config/**"
  ]
}
```

**Modifier 2 — ACA not selected, exclude all ACA-specific files:**
```json
{
  "condition": "(!UseAzureContainerInfra)",
  "exclude": [
    "infra/main.aca.bicep",
    "infra/main.aca.bicepparam",
    "infra/deploy.aca.ps1",
    "infra/deploy.aca.sh",
    "infra/bootstrap.ps1",
    "infra/bootstrap.sh",
    "infra/README.aca.md",
    "infra/modules/aca-app.bicep",
    "infra/modules/aca-environment.bicep",
    "infra/modules/container-registry.bicep",
    ".github/workflows/deploy.aca.yml",
    ".github/workflows/pr.aca.yml",
    ".github/workflows/infra.yml",
    "config/sync-appconfig.aca.sh",
    "WebProject.Api/Dockerfile"
  ]
}
```

**Modifier 3 — App Service not selected, exclude all App Service-specific files:**
```json
{
  "condition": "(!UseAzureAppServiceInfra)",
  "exclude": [
    "infra/main.bicep",
    "infra/main.bicepparam",
    "infra/deploy.ps1",
    "infra/deploy.sh",
    "infra/README.md",
    "infra/modules/app-service.bicep",
    ".github/workflows/deploy.yml",
    ".github/workflows/pr.yml",
    "config/sync-appconfig.sh"
  ]
}
```

**Logic verification:**

| UseAzureContainerInfra | UseAzureAppServiceInfra | Modifier 1 | Modifier 2 | Modifier 3 | Result |
|---|---|---|---|---|---|
| false | false | ✅ fires (excludes all infra) | ✅ fires (redundant) | ✅ fires (redundant) | No infra |
| true | false | ❌ | ❌ | ✅ fires (excludes App Service files) | ACA infra only |
| false | true | ❌ | ✅ fires (excludes ACA files) | ❌ | App Service infra only |
| true | true | ❌ | ❌ | ❌ | Both (unsupported, not enforced) |

---

## ACA-specific Bicep details

### `infra/main.aca.bicep` differences from `infra/main.bicep`

**Removed param:** `appServicePlanSku`  
**Added params:**
```bicep
@description('Container image for the prod Container App (preserved across infra re-runs).')
param prodContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container image for the staging Container App (preserved across infra re-runs).')
param stgContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
```

**Replaced:** Single `appConfiguration` module with two:
- `appConfiguration` — staging store, tagged `environment: staging` — receives shared/staging/PR labels
- `appConfigurationProd` — production store, tagged `environment: production` — receives production label only

**Replaced:** `appService` module with: `acr`, `acaEnvProd`, `acaEnvStg`, `acaAppProd`, `acaAppStg`

**Updated outputs:** `apiUrl` → `prodApiUrl` + `stagingApiUrl`; adds `acrLoginServer`, `prodAppConfigStoreName`, `stagingAppConfigStoreName`

### `infra/modules/app-configuration.bicep`
No change — already identical between MacroFoundry and the template.

---

## CI/CD differences

### `deploy.aca.yml` vs `deploy.yml`

| Step | App Service | ACA |
|---|---|---|
| Build API | `dotnet publish` → artifact | `docker build` + `docker push` to ACR |
| Get API URLs | Hardcoded from known slot hostnames | `az containerapp show --query ingress.fqdn` |
| Deploy to staging | `azure/webapps-deploy@v3` | `az containerapp update --image` |
| Set CORS | `az webapp config appsettings set` | `az containerapp update --set-env-vars` |
| Promote to prod | Slot swap | Pin current revision → new revision at 0% → shift 100% → health check → deactivate old revisions |
| Infra auto-deploy | Manual only | `infra.yml` on push to `infra/**` |

### `pr.aca.yml` vs `pr.yml`

| Step | App Service | ACA |
|---|---|---|
| Build API | `dotnet publish` → package | `docker build` + push to ACR |
| Provision PR env | Create App Service slot | Create Container App (`az containerapp create`) |
| Update PR env | Deploy to slot | `az containerapp update --image` |
| Teardown | Delete slot | `az containerapp delete` |

### `sync-appconfig.aca.sh` vs `sync-appconfig.sh`

The critical difference: store resolution at the top of the script.

**App Service version (one store):**
```bash
STORE=$(az appconfig list -g "$RG" --query '[0].name' -o tsv)
```

**ACA version (two stores, resolved by environment tag):**
```bash
if [[ "$SCOPE" == "production" ]]; then
  _ENV_TAG="production"
else
  _ENV_TAG="staging"
fi
STORE=$(az appconfig list -g "$RG" \
  --query "[?tags.environment=='${_ENV_TAG}'].name | [0]" -o tsv)
```

---

## Bootstrap scripts (`infra/bootstrap.ps1`, `infra/bootstrap.sh`) — ACA only

Run once before first CI/CD deployment. Not needed for App Service flavor.

1. Preflight: checks `az` and `gh` CLIs are present and authenticated
2. Prompts for SQL admin password (or reads `AZURE_SQL_ADMIN_PASSWORD` env var)
3. Sets `AZURE_SQL_ADMIN_PASSWORD` as a GitHub Actions secret via `gh secret set`
4. Registers `Microsoft.App` and `Microsoft.ContainerRegistry` resource providers
5. Compiles and deploys the Bicep stack
6. Prints next steps (push a commit to trigger first container deployment)

---

## Usage

**Scaffold with ACA infrastructure:**
```bash
dotnet new webproject -n MyApp --UseAzureContainerInfra true --AzureResourcePrefix myapp
```

**Scaffold with App Service infrastructure (existing):**
```bash
dotnet new webproject -n MyApp --UseAzureAppServiceInfra true --AzureResourcePrefix myapp
```

**Scaffold without infrastructure (default):**
```bash
dotnet new webproject -n MyApp
```
