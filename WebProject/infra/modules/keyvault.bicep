@description('Name of the Key Vault (globally unique, 3-24 chars).')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Principal ID of the managed identity to grant secret access.')
param managedIdentityPrincipalId string

@description('SQL connection string to store as a secret.')
@secure()
param sqlConnectionString string

// Built-in role: Key Vault Secrets User (read secrets)
var kvSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true  // Use RBAC, not access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, managedIdentityPrincipalId, kvSecretsUserRoleId)
  scope: vault
  properties: {
    roleDefinitionId: kvSecretsUserRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource vaultLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${vault.name}-lock'
  scope: vault
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevent accidental deletion of Key Vault and its secrets.'
  }
}

resource secretSqlConnection 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'sql-connection-string'
  properties: {
    value: sqlConnectionString
  }
}

output name string = vault.name
output vaultUri string = vault.properties.vaultUri
output sqlConnectionStringSecretUri string = secretSqlConnection.properties.secretUri