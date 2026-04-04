@description('Name of the Container App.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Resource ID of the ACA Managed Environment.')
param environmentId string

@description('Full image reference, e.g. crprefix.azurecr.io/api:abc123.')
param containerImage string

@description('Full resource ID of the user-assigned managed identity.')
param managedIdentityId string

@description('Client ID of the managed identity (for AZURE_CLIENT_ID env var).')
param managedIdentityClientId string

@description('ASPNETCORE_ENVIRONMENT value.')
param aspnetcoreEnvironment string

@description('App Configuration endpoint URL.')
param appConfigurationEndpoint string

@description('Key Vault URI for the SQL connection string secret (versionless).')
param sqlConnectionStringSecretUri string

@description('ACR login server, e.g. crprefix.azurecr.io. Used for managed-identity image pulls.')
param acrLoginServer string

@description('Initial CORS allowed origin (SWA URL). Can be empty string initially.')
param corsAllowedOrigins string = ''

@description('Minimum number of replicas.')
@minValue(0)
param minReplicas int = 0

@description('Maximum number of replicas.')
@minValue(1)
@maxValue(300)
param maxReplicas int = 3

@description('Revision mode: Single or Multiple.')
@allowed(['Single', 'Multiple'])
param revisionMode string = 'Single'

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      activeRevisionsMode: revisionMode
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
      secrets: [
        {
          name: 'sql-connection-string'
          keyVaultUrl: sqlConnectionStringSecretUri
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: containerImage
          env: concat(
            [
              { name: 'ASPNETCORE_ENVIRONMENT', value: aspnetcoreEnvironment }
              { name: 'AZURE_CLIENT_ID', value: managedIdentityClientId }
              { name: 'AppConfiguration__Endpoint', value: appConfigurationEndpoint }
              { name: 'ConnectionStrings__DefaultConnection', secretRef: 'sql-connection-string' }
            ],
            corsAllowedOrigins != '' ? [{ name: 'Cors__AllowedOrigins', value: corsAllowedOrigins }] : []
          )
          probes: [
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 6
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/alive'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 30
              failureThreshold: 3
            }
          ]
          resources: {
            cpu: any(json('0.5'))
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output name string = app.name
