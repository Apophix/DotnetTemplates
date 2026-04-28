using './main.bicep'

param location = 'centralus'

param staticWebAppLocation = 'centralus'

param sqlAdminLogin = 'sqladmin'

// App Service Plan SKU — must be Standard or Premium for slot support.
// S1 is sufficient to start; scale up to P1v3/P2v3 when needed.
param appServicePlanSku = { name: 'S1', tier: 'Standard', capacity: 1 }

// sqlAdminPassword must be passed at deploy time:
//   ./infra/azure-app-service/deploy.ps1
// or
//   ./infra/azure-app-service/deploy.sh
