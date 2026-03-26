@description('Name of the App Configuration store.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Principal ID of the managed identity to grant data reader access.')
param managedIdentityPrincipalId string

@description('App Configuration SKU.')
@allowed(['Free', 'Developer', 'Standard', 'Premium'])
param sku string = 'Developer'

// Built-in role: App Configuration Data Reader
var appConfigReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '516239f1-63e1-4d78-a4de-a74fb236a071')

resource configStore 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
}

// Grant the managed identity read access to feature flags and config values
resource dataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(configStore.id, managedIdentityPrincipalId, appConfigReaderRoleId)
  scope: configStore
  properties: {
    roleDefinitionId: appConfigReaderRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output name string = configStore.name
output endpoint string = configStore.properties.endpoint
