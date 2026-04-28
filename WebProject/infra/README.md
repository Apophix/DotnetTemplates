# WebProject — Infrastructure

Azure infrastructure for WebProject, defined entirely in Bicep at subscription scope.

## Choose your hosting option

| Option | Directory | Best for |
|--------|-----------|----------|
| **Azure App Service** | [`azure-app-service/`](azure-app-service/) | Teams familiar with PaaS; slot-based deployments; no container registry required |
| **Azure Container Apps** | [`azure-container-apps/`](azure-container-apps/) | Container-first teams; ACA scaling model; works with existing ACR workflows |
| **Docker Compose (local dev only)** | [`containers-generic/`](containers-generic/) | Local dev without Aspire or Azure; docker-only workflow |

Each option directory is self-contained with its own `main.bicep`, `main.bicepparam`,
`deploy.ps1`, `deploy.sh`, and `README.md`.

## Shared structure

```
infra/
  bicepconfig.json            Linter rules + experimental features (userDefinedFunctions)
  bootstrap.ps1               One-time setup: resource providers, GitHub secrets, first deploy (Windows)
  bootstrap.sh                One-time setup: resource providers, GitHub secrets, first deploy (Linux/macOS)
  README.md                   This file

  azure-app-service/          App Service + slots + Static Web App
  azure-container-apps/       ACA environments + Container Registry + Static Web App
  containers-generic/         docker-compose.yml for local-only dev (no Azure)

  modules/                    Shared Bicep modules (used by both Azure options)
    managed-identity.bicep
    sql-server.bicep
    sql-database.bicep
    keyvault.bicep
    storage.bicep
    app-service.bicep
    aca-app.bicep
    aca-environment.bicep
    container-registry.bicep
    static-web-app.bicep
```

`bicepconfig.json` lives at the `infra/` root. Bicep resolves config by searching upward, so
all files in subdirectories inherit it automatically — no copies needed.

## Common resources (both Azure options)

Both Azure hosting options provision the same shared resources:

- **Managed identity** — used by App Service / ACA and Key Vault
- **SQL Server** — one logical server, two databases (`prod`, `stg`)
- **Key Vault (prod + staging)** — `CanNotDelete` lock; production secrets isolated from staging
- **Storage Account** — blob container for uploads
- **Static Web App** — React SPA (Free tier; PR previews built-in)

The Key Vault and SQL database resources carry `CanNotDelete` locks to prevent accidental deletion
during stack operations. Combined with `--action-on-unmanage detachAll`, resources removed from
the Bicep template are detached (not deleted) — you clean them up manually.

## First deploy

**Windows:**
```powershell
# App Service
.\infra\bootstrap.ps1 -Variant AppService -Location centralus

# Container Apps
.\infra\bootstrap.ps1 -Variant ContainerApps -Location centralus
```

**Linux/macOS:**
```bash
# App Service
./infra/bootstrap.sh --variant app-service --location centralus

# Container Apps
./infra/bootstrap.sh --variant container-apps --location centralus
```

Bootstrap registers resource providers, sets the `AZURE_SQL_ADMIN_PASSWORD` GitHub secret, and
deploys the initial infrastructure stack. Run it once; subsequent deploys use the variant's
`deploy.ps1` / `deploy.sh` directly.

## Federated identity (OIDC) — one-time GitHub Actions setup

Both Azure options use **federated credentials** for GitHub Actions. No client secrets needed.
After the first deploy, run this once per option you intend to use:

```bash
# Replace <org>/<repo> with your GitHub repository
IDENTITY_RG="rg-webprojectazureprefix"
IDENTITY_NAME="id-webprojectazureprefix"

# Federated credential for main branch deploys
az identity federated-credential create \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$IDENTITY_RG" \
  --name github-main \
  --issuer https://token.actions.githubusercontent.com \
  --subject repo:<org>/<repo>:ref:refs/heads/main \
  --audiences api://AzureADTokenExchange

# Federated credential for pull requests
az identity federated-credential create \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$IDENTITY_RG" \
  --name github-prs \
  --issuer https://token.actions.githubusercontent.com \
  --subject repo:<org>/<repo>:pull_request \
  --audiences api://AzureADTokenExchange
```

Then add these **GitHub Actions secrets** (repository Settings → Secrets):

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | Client ID of `id-webprojectazureprefix` |
| `AZURE_TENANT_ID` | Your Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |

## Linter and compiled artifacts

`bicepconfig.json` enables strict linter rules and the `userDefinedFunctions` experimental
feature (used by `func kvRef()` in `app-service.bicep`).

Compiled ARM JSON (`infra/**/*.json`) is gitignored — never commit generated files.

