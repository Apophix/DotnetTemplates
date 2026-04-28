using './main.bicep'

param location = 'centralus'

param staticWebAppLocation = 'centralus'

param sqlAdminLogin = 'sqladmin'

// sqlAdminPassword must be passed at deploy time:
//   ./infra/azure-container-apps/deploy.ps1
// or
//   ./infra/azure-container-apps/deploy.sh
// prodContainerImage and stgContainerImage are managed by CI/CD and bootstrap scripts.
