# azure-app-service — Infrastructure

Provisions the full Azure App Service hosting stack using Bicep deployment stacks.

## Resources provisioned

| Resource | Name pattern | Notes |
|----------|-------------|-------|
| Resource Group | `rg-webprojectazureprefix` | All resources below live here |
| User-Assigned Managed Identity | `id-webprojectazureprefix` | Used by App Service and Key Vault |
| SQL Server | `sql-webprojectazureprefix` | One server, two databases |
| SQL Database (prod) | `sqldb-webprojectazureprefix-prod` | `CanNotDelete` lock |
| SQL Database (staging) | `sqldb-webprojectazureprefix-stg` | `CanNotDelete` lock |
| Key Vault (prod) | `kv-webprojectazureprefix-prod-<suffix>` | `CanNotDelete` lock |
| Key Vault (staging) | `kv-webprojectazureprefix-stg-<suffix>` | `CanNotDelete` lock |
| Storage Account | `stwebprojectazureprefix<suffix>` | |
| App Service Plan | `asp-webprojectazureprefix` | S1 Standard (configurable) |
| App Service (API) | `app-webprojectazureprefix-api` | With a `staging` slot |
| Static Web App | `swa-webprojectazureprefix` | React SPA |

### Topology choice: slot vs separate resource

`app-service.bicep` supports two staging topologies. Choose one before deploying:

- **Option A — deployment slot** (`/staging` slot on the same App Service plan): Lower cost,
  same plan SKU. The staging slot and prod share the same compute. Use `S1` or higher.
- **Option B — separate App Service resource**: Full isolation (separate scale, separate SKU).
  Higher cost but true production-parity staging.

Edit `main.bicep` or the `app-service.bicep` module directly to set your preference.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (`az login`)
- Contributor role on the target subscription
- `az bicep install` (or Bicep CLI ≥ 0.30)
- [GitHub CLI](https://cli.github.com) (`gh auth login`) — for the bootstrap script

## First deploy (one-time setup)

Run bootstrap from the repo root. This registers resource providers, sets the `AZURE_SQL_ADMIN_PASSWORD` GitHub secret, and deploys the initial infrastructure stack:

```powershell
.\infra\bootstrap.ps1 -Variant AppService -Location centralus
```

```bash
./infra/bootstrap.sh --variant app-service --location centralus
```

## Subsequent deploys

```powershell
.\infra\azure-app-service\deploy.ps1 -Location centralus
```

```bash
./infra/azure-app-service/deploy.sh --location centralus
```

Both scripts use `az stack sub create` with `--action-on-unmanage detachAll`. Resources removed
from the Bicep template are **detached** from the stack (not deleted). Delete them manually.

## CI/CD secrets and variables required

| Name | Type | Description |
|------|------|-------------|
| `AZURE_CLIENT_ID` | Secret | Federated identity client ID |
| `AZURE_TENANT_ID` | Secret | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Azure subscription ID |
| `AZURE_SQL_ADMIN_PASSWORD` | Secret | SQL SA password (set by bootstrap) |

> **Federated identity setup**: Run `infra/bootstrap.ps1` — it creates the managed identity and
> configures the OIDC trust for GitHub Actions. No service principal client secrets needed.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `location` | *(required)* | Azure region |
| `sqlAdminLogin` | `sqladmin` | SQL Server SA login |
| `sqlAdminPassword` | *(required, secure)* | SQL Server SA password |
| `staticWebAppLocation` | `eastus2` | SWA must be in a supported region |
| `appServicePlanSku` | `S1 Standard` | Must be S1+ for deployment slots |

Edit `main.bicepparam` to override defaults.
