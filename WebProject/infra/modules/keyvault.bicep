@description('Name of the Key Vault (globally unique, 3-24 chars).')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Principal ID of the managed identity to grant secret access.')
param managedIdentityPrincipalId string

@description('Also grant Key Vault Secrets Officer (write) to the managed identity. Required for CI/CD to store secrets (e.g. PR connection strings).')
param allowSecretWrite bool = false

@description('SQL connection string to store as a secret.')
@secure()
param sqlConnectionString string

// Built-in role: Key Vault Secrets User (read secrets)
var kvSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
// Built-in role: Key Vault Secrets Officer (read + write secrets)
var kvSecretsOfficerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')

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

// Grant the managed identity permission to read secrets (used by App Service Key Vault references)
resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, managedIdentityPrincipalId, kvSecretsUserRoleId)
  scope: vault
  properties: {
    roleDefinitionId: kvSecretsUserRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource kvSecretsOfficerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (allowSecretWrite) {
  name: guid(vault.id, managedIdentityPrincipalId, kvSecretsOfficerRoleId)
  scope: vault
  properties: {
    roleDefinitionId: kvSecretsOfficerRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
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
