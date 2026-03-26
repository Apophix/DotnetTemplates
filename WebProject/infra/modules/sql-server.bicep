@description('Name of the Azure SQL logical server.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('SQL administrator login name.')
param adminLogin string

@description('SQL administrator password.')
@secure()
param adminPassword string

resource server 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Allow Azure services (App Service, GitHub Actions) to connect
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: server
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output serverName string = server.name
output serverFqdn string = server.properties.fullyQualifiedDomainName
