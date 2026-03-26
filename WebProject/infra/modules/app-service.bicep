@description('Name of the App Service Plan.')
param planName string

@description('Name of the API Web App.')
param apiAppName string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('App Service Plan SKU. Must be Standard or Premium to support deployment slots.')
param planSku object

@description('Resource ID of the user-assigned managed identity.')
param managedIdentityId string

@description('Client ID of the user-assigned managed identity.')
param managedIdentityClientId string

@description('Key Vault name for the production slot.')
param prodKeyVaultName string

@description('Key Vault name for the staging slot (and all ephemeral PR slots).')
param stagingKeyVaultName string

@description('App Configuration endpoint URL.')
param appConfigurationEndpoint string

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func kvRef(vaultName string, secretName string) string =>
  '@Microsoft.KeyVault(VaultName=${vaultName};SecretName=${secretName})'

// Settings shared by every slot
var commonSettings = [
  { name: 'AZURE_CLIENT_ID', value: managedIdentityClientId }
]

// Settings that vary per slot — marked sticky so they survive a swap
var prodApiSettings = concat(commonSettings, [
  { name: 'ASPNETCORE_ENVIRONMENT', value: 'Production' }
  { name: 'ConnectionStrings__DefaultConnection', value: kvRef(prodKeyVaultName, 'sql-connection-string') }
  { name: 'AppConfiguration__Endpoint', value: appConfigurationEndpoint }
])

var stagingApiSettings = concat(commonSettings, [
  { name: 'ASPNETCORE_ENVIRONMENT', value: 'Staging' }
  { name: 'ConnectionStrings__DefaultConnection', value: kvRef(stagingKeyVaultName, 'sql-connection-string') }
  { name: 'AppConfiguration__Endpoint', value: appConfigurationEndpoint }
])

// Settings that must not travel with swapped content
var stickyApiSettingNames = [
  'ASPNETCORE_ENVIRONMENT'
  'ConnectionStrings__DefaultConnection'
  'AppConfiguration__Endpoint'
]

// ---------------------------------------------------------------------------
// App Service Plan
// ---------------------------------------------------------------------------

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: planSku
  properties: {
    reserved: true // Required for Linux
  }
}

// ---------------------------------------------------------------------------
// API Web App
// ---------------------------------------------------------------------------

resource apiApp 'Microsoft.Web/sites@2023-12-01' = {
  name: apiAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      appSettings: prodApiSettings
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }
}

// Prevent sticky settings from travelling with a slot swap
resource apiStickySettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: apiApp
  name: 'slotConfigNames'
  properties: {
    appSettingNames: stickyApiSettingNames
  }
}

// Staging slot — also the base for ephemeral PR slots created by CI/CD
resource apiStagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: apiApp
  name: 'staging'
  location: location
  tags: union(tags, { environment: 'staging' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      appSettings: stagingApiSettings
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output apiUrl string = 'https://${apiApp.properties.defaultHostName}'
output apiAppName string = apiApp.name
