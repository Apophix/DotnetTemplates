@description('Storage account name (lowercase alphanumeric only, max 24 chars).')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Principal ID of the managed identity to grant blob access.')
param managedIdentityPrincipalId string

// Built-in role: Storage Blob Data Contributor
var blobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // Required for some SDK operations; restrict further when possible
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

// Container for blob storage — rename or add containers as needed
resource defaultContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'uploads'
  properties: {
    publicAccess: 'None'
  }
}

resource blobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentityPrincipalId, blobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: blobDataContributorRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output accountName string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
