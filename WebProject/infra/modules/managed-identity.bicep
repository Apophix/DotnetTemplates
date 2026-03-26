@description('Name of the user-assigned managed identity.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output principalId string = identity.properties.principalId
output clientId string = identity.properties.clientId
output resourceId string = identity.id
