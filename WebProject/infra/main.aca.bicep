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

@description('Container image for the prod Container App (preserved across infra re-runs).')
param prodContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container image for the staging Container App (preserved across infra re-runs).')
param stgContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

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

module identity 'modules/managed-identity.bicep' = {
  name: 'identity'
  scope: rg
  params: {
    name: 'id-${prefix}'
    location: location
    tags: tags
  }
}

module sqlServer 'modules/sql-server.bicep' = {
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

module sqlDbProd 'modules/sql-database.bicep' = {
  name: 'sqlDbProd'
  scope: rg
  params: {
    serverName: sqlServer.outputs.serverName
    databaseName: 'sqldb-${prefix}-prod'
    location: location
    tags: union(tags, { environment: 'production' })
  }
}

module sqlDbStg 'modules/sql-database.bicep' = {
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
module kvProd 'modules/keyvault.bicep' = {
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

module kvStg 'modules/keyvault.bicep' = {
  name: 'kvStg'
  scope: rg
  params: {
    name: 'kv-${prefix}-stg-${take(uniqueSuffix, 11)}'
    location: location
    tags: union(tags, { environment: 'staging' })
    managedIdentityPrincipalId: identity.outputs.principalId
    sqlConnectionString: 'Server=tcp:${sqlServer.outputs.serverFqdn},1433;Initial Catalog=${sqlDbStg.outputs.databaseName};User ID=${sqlAdminLogin};Password=${sqlAdminPassword};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    allowSecretWrite: true  // CI/CD writes PR connection strings into the staging KV
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: 'st${prefix}${uniqueSuffix}'
    location: location
    tags: tags
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// Staging store — shared, staging, and PR labels (used by staging + all PR Container Apps)
module appConfiguration 'modules/app-configuration.bicep' = {
  name: 'appConfiguration'
  scope: rg
  params: {
    name: 'appconfig-${prefix}-${take(uniqueSuffix, 8)}'
    location: location
    tags: union(tags, { environment: 'staging' })
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// Production store — production label only; isolated from staging CI writes
module appConfigurationProd 'modules/app-configuration.bicep' = {
  name: 'appConfigurationProd'
  scope: rg
  params: {
    name: 'appconfig-${prefix}-prod-${take(uniqueSuffix, 8)}'
    location: location
    tags: union(tags, { environment: 'production' })
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

module acr 'modules/container-registry.bicep' = {
  name: 'containerRegistry'
  scope: rg
  params: {
    name: 'cr${prefix}'
    location: location
    tags: tags
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

module acaEnvProd 'modules/aca-environment.bicep' = {
  name: 'acaEnvProd'
  scope: rg
  params: {
    name: 'env-${prefix}-prod'
    location: location
    tags: union(tags, { environment: 'production' })
  }
}

module acaEnvStg 'modules/aca-environment.bicep' = {
  name: 'acaEnvStg'
  scope: rg
  params: {
    name: 'env-${prefix}-stg'
    location: location
    tags: union(tags, { environment: 'staging' })
  }
}

module acaAppProd 'modules/aca-app.bicep' = {
  name: 'acaAppProd'
  scope: rg
  params: {
    name: 'app-${prefix}-api'
    location: location
    tags: union(tags, { environment: 'production' })
    environmentId: acaEnvProd.outputs.environmentId
    containerImage: prodContainerImage
    managedIdentityId: identity.outputs.resourceId
    managedIdentityClientId: identity.outputs.clientId
    aspnetcoreEnvironment: 'Production'
    appConfigurationEndpoint: appConfigurationProd.outputs.endpoint
    sqlConnectionStringSecretUri: kvProd.outputs.sqlConnectionStringSecretUri
    acrLoginServer: acr.outputs.loginServer
    minReplicas: 1
    revisionMode: 'Multiple'
  }
  dependsOn: [kvProd]
}

module acaAppStg 'modules/aca-app.bicep' = {
  name: 'acaAppStg'
  scope: rg
  params: {
    name: 'app-${prefix}-api-stg'
    location: location
    tags: union(tags, { environment: 'staging' })
    environmentId: acaEnvStg.outputs.environmentId
    containerImage: stgContainerImage
    managedIdentityId: identity.outputs.resourceId
    managedIdentityClientId: identity.outputs.clientId
    aspnetcoreEnvironment: 'Staging'
    appConfigurationEndpoint: appConfiguration.outputs.endpoint
    sqlConnectionStringSecretUri: kvStg.outputs.sqlConnectionStringSecretUri
    acrLoginServer: acr.outputs.loginServer
    minReplicas: 0
    revisionMode: 'Single'
  }
  dependsOn: [kvStg]
}

module staticWebApp 'modules/static-web-app.bicep' = {
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
output prodApiUrl string = 'https://${acaAppProd.outputs.fqdn}'
output stagingApiUrl string = 'https://${acaAppStg.outputs.fqdn}'
output acrLoginServer string = acr.outputs.loginServer
output webUrl string = 'https://${staticWebApp.outputs.defaultHostname}'
output staticWebAppName string = staticWebApp.outputs.name
output prodKeyVaultName string = kvProd.outputs.name
output stagingKeyVaultName string = kvStg.outputs.name
output prodAppConfigStoreName string = appConfigurationProd.outputs.name
output stagingAppConfigStoreName string = appConfiguration.outputs.name
output sqlServerFqdn string = sqlServer.outputs.serverFqdn
output managedIdentityClientId string = identity.outputs.clientId
