// XiaoCao — Low-Cost Chat UI for Azure AI Foundry
// Provisions a Static Web App + a Function App (managed identity) that talks to a
// Foundry agent. Two cost tiers via `environmentType`:
//   - test:       SWA Free  ($0); frontend calls the Function App URL directly (CORS).
//   - production: SWA Standard; Function App linked as the /api backend.
// RBAC to the Foundry resource is granted by the provisioning script afterwards.

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Deployment cost tier.')
@allowed([
  'test'
  'production'
])
param environmentType string = 'test'

@description('Short prefix used to name resources (3-11 lowercase alphanumerics).')
@minLength(3)
@maxLength(11)
param namePrefix string = 'xiaocao'

@description('Azure AI Foundry project endpoint, e.g. https://<project>.services.ai.azure.com/api/projects/<name>.')
param foundryEndpoint string

@description('Name of the Foundry agent the UI will talk to.')
param agentName string

@description('Location for the Static Web App (must be a SWA-supported region).')
param swaLocation string = 'eastus2'

var suffix = uniqueString(resourceGroup().id)
var storageName = toLower('${namePrefix}${take(suffix, 8)}sa')
var functionAppName = '${namePrefix}-func-${take(suffix, 6)}'
var planName = '${namePrefix}-plan-${take(suffix, 6)}'
var insightsName = '${namePrefix}-ai-${take(suffix, 6)}'
var swaName = '${namePrefix}-swa-${take(suffix, 6)}'

// Production links the Function App as the SWA /api backend (Standard tier only).
// Test uses the Free tier, which does not support linked backends.
var isProduction = environmentType == 'production'
var swaSkuName = isProduction ? 'Standard' : 'Free'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: insightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    reserved: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Node|20'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: ['*']
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: insights.properties.ConnectionString
        }
        {
          name: 'AZURE_AI_FOUNDRY_ENDPOINT'
          value: foundryEndpoint
        }
        {
          name: 'AZURE_AI_AGENT_NAME'
          value: agentName
        }
      ]
    }
  }
}

resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: swaName
  location: swaLocation
  sku: {
    name: swaSkuName
    tier: swaSkuName
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
  }
}

// Link the Function App as the SWA API backend so /api/* is proxied to it.
// Only supported on the Standard (production) tier.
resource swaBackend 'Microsoft.Web/staticSites/linkedBackends@2023-12-01' = if (isProduction) {
  parent: swa
  name: 'default'
  properties: {
    backendResourceId: functionApp.id
    region: location
  }
}

output environmentType string = environmentType
output functionAppName string = functionApp.name
output functionAppHostname string = functionApp.properties.defaultHostName
output functionAppPrincipalId string = functionApp.identity.principalId
output swaName string = swa.name
output swaDefaultHostname string = swa.properties.defaultHostname
