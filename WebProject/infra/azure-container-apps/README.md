# azure-container-apps — Infrastructure

Provisions the full Azure Container Apps hosting stack using Bicep deployment stacks.

## Resources provisioned

| Resource | Name pattern | Notes |
|----------|-------------|-------|
| Resource Group | `rg-webprojectazureprefix` | All resources below live here |
| User-Assigned Managed Identity | `id-webprojectazureprefix` | Used by ACA and Key Vault |
| SQL Server | `sql-webprojectazureprefix` | One server, two databases |
| SQL Database (prod) | `sqldb-webprojectazureprefix-prod` | `CanNotDelete` lock |
| SQL Database (staging) | `sqldb-webprojectazureprefix-stg` | `CanNotDelete` lock |
| Key Vault (prod) | `kv-webprojectazureprefix-prod-<suffix>` | `CanNotDelete` lock |
| Key Vault (staging) | `kv-webprojectazureprefix-stg-<suffix>` | `CanNotDelete` lock |
| Storage Account | `stwebprojectazureprefix<suffix>` | |
| Container Registry | `crwebprojectazureprefix` | Basic SKU; managed identity pull |
| ACA Environment (prod) | `env-webprojectazureprefix-prod` | Consumption plan |
| ACA Environment (staging) | `env-webprojectazureprefix-stg` | Consumption plan |
| Container App API (prod) | `app-webprojectazureprefix-api` | Min 1 replica; Multiple revision mode |
| Container App API (staging) | `app-webprojectazureprefix-api-stg` | Min 0 replicas; Single revision mode |
| Static Web App | `swa-webprojectazureprefix` | React SPA |

## First deploy — placeholder image

On the initial deploy the Container Apps are created with the
`mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` placeholder image. This allows
Bicep to provision all resources without requiring the application image to exist in ACR first.

The pipeline replaces the image on the first push to `main`. To skip the placeholder, pre-push
an image to ACR and pass `prodContainerImage` / `stgContainerImage` as Bicep parameters.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (`az login`)
- Contributor role on the target subscription
- `az bicep install` (or Bicep CLI ≥ 0.30)
- [GitHub CLI](https://cli.github.com) (`gh auth login`) — for the bootstrap script

## First deploy (one-time setup)

Run bootstrap from the repo root. This registers resource providers, sets the `AZURE_SQL_ADMIN_PASSWORD` GitHub secret, and deploys the initial infrastructure stack:

```powershell
.\infra\bootstrap.ps1 -Variant ContainerApps -Location centralus
```

```bash
./infra/bootstrap.sh --variant container-apps --location centralus
```

## Subsequent deploys

```powershell
.\infra\azure-container-apps\deploy.ps1 -Location centralus
```

```bash
./infra/azure-container-apps/deploy.sh --location centralus
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
| `prodContainerImage` | placeholder | Override with your ACR image on first deploy |
| `stgContainerImage` | placeholder | Override with your ACR image on first deploy |

Edit `main.bicepparam` to override defaults.
