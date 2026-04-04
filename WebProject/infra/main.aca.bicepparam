using './main.aca.bicep'

param location = 'centralus'

param staticWebAppLocation = 'centralus'

param sqlAdminLogin = 'sqladmin'

// sqlAdminPassword must be passed at deploy time:
//   ./infra/deploy.ps1
// or
//   ./infra/deploy.sh
// prodContainerImage and stgContainerImage are managed by infra.yml and bootstrap scripts.
