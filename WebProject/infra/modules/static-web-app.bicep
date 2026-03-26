@description('Name of the Static Web App.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

resource staticSite 'Microsoft.Web/staticSites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    // Deployment is driven entirely by GitHub Actions (azure/static-web-apps-deploy).
    // No repository/branch wired here — CI retrieves the deployment token at runtime
    // via: az staticwebapp secrets list --name <name> --resource-group <rg>
  }
}

output name string = staticSite.name
output defaultHostname string = staticSite.properties.defaultHostname
