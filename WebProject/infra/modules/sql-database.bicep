@description('Name of the existing SQL logical server to create the database on.')
param serverName string

@description('Name of the database to create.')
param databaseName string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

resource server 'Microsoft.Sql/servers@2023-05-01-preview' existing = {
  name: serverName
}

resource database 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: server
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5 // 5 DTUs — DTU purchase model, Basic service tier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    requestedBackupStorageRedundancy: 'Local'
  }
}

output databaseName string = database.name
