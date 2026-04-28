targetScope = 'subscription'

@description('The Azure region to deploy resources into.')
param location string

@description('SQL Server administrator login name.')
param sqlAdminLogin string

@description('SQL Server administrator password.')
@secure()
param sqlAdminPassword string

@description('Azure region for the Static Web App. Must be one of the supported SWA regions (eastus2, westus2, centralus, westeurope, eastasia).')
param staticWebAppLocation string = 'eastus2'

@description('App Service Plan SKU. Must be Standard or Premium to support deployment slots.')
param appServicePlanSku object = { name: 'S1', tier: 'Standard', capacity: 1 }

// ---------------------------------------------------------------------------
// Derived values
// ---------------------------------------------------------------------------

var prefix = 'webprojectazureprefix'
var uniqueSuffix = uniqueString(rg.id)

var tags = {
  project: 'WebProject'
  managedBy: 'bicep'
}

// ---------------------------------------------------------------------------
// Resource group
// ---------------------------------------------------------------------------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${prefix}'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Shared resources
// ---------------------------------------------------------------------------

module identity '../modules/managed-identity.bicep' = {
  name: 'identity'
  scope: rg
  params: {
    name: 'id-${prefix}'
    location: location
    tags: tags
  }
}

module sqlServer '../modules/sql-server.bicep' = {
  name: 'sqlServer'
  scope: rg
  params: {
    name: 'sql-${prefix}'
    location: location
    tags: tags
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
  }
}

module sqlDbProd '../modules/sql-database.bicep' = {
  name: 'sqlDbProd'
  scope: rg
  params: {
    serverName: sqlServer.outputs.serverName
    databaseName: 'sqldb-${prefix}-prod'
    location: location
    tags: union(tags, { environment: 'production' })
  }
}

module sqlDbStg '../modules/sql-database.bicep' = {
  name: 'sqlDbStg'
  scope: rg
  params: {
    serverName: sqlServer.outputs.serverName
    databaseName: 'sqldb-${prefix}-stg'
    location: location
    tags: union(tags, { environment: 'staging' })
  }
}

// Two Key Vaults — prod secrets never touch staging/ephemeral environments
module kvProd '../modules/keyvault.bicep' = {
  name: 'kvProd'
  scope: rg
  params: {
    name: 'kv-${prefix}-prod-${take(uniqueSuffix, 11)}'
    location: location
    tags: union(tags, { environment: 'production' })
    managedIdentityPrincipalId: identity.outputs.principalId
    sqlConnectionString: 'Server=tcp:${sqlServer.outputs.serverFqdn},1433;Initial Catalog=${sqlDbProd.outputs.databaseName};User ID=${sqlAdminLogin};Password=${sqlAdminPassword};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}

module kvStg '../modules/keyvault.bicep' = {
  name: 'kvStg'
  scope: rg
  params: {
    name: 'kv-${prefix}-stg-${take(uniqueSuffix, 11)}'
    location: location
    tags: union(tags, { environment: 'staging' })
    managedIdentityPrincipalId: identity.outputs.principalId
    sqlConnectionString: 'Server=tcp:${sqlServer.outputs.serverFqdn},1433;Initial Catalog=${sqlDbStg.outputs.databaseName};User ID=${sqlAdminLogin};Password=${sqlAdminPassword};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}

module storage '../modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: 'st${prefix}${uniqueSuffix}'
    location: location
    tags: tags
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

module appService '../modules/app-service.bicep' = {
  name: 'appService'
  scope: rg
  params: {
    planName: 'asp-${prefix}'
    apiAppName: 'app-${prefix}-api'
    location: location
    tags: tags
    planSku: appServicePlanSku
    managedIdentityId: identity.outputs.resourceId
    managedIdentityClientId: identity.outputs.clientId
    prodKeyVaultName: kvProd.outputs.name
    stagingKeyVaultName: kvStg.outputs.name
  }
}

module staticWebApp '../modules/static-web-app.bicep' = {
  name: 'staticWebApp'
  scope: rg
  params: {
    name: 'swa-${prefix}'
    location: staticWebAppLocation
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output resourceGroupName string = rg.name
output apiUrl string = appService.outputs.apiUrl
output webUrl string = 'https://${staticWebApp.outputs.defaultHostname}'
output staticWebAppName string = staticWebApp.outputs.name
output prodKeyVaultName string = kvProd.outputs.name
output stagingKeyVaultName string = kvStg.outputs.name
output sqlServerFqdn string = sqlServer.outputs.serverFqdn
output managedIdentityClientId string = identity.outputs.clientId
