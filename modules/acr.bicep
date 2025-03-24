@description('Name of the Azure Container Registry')
param acrName string

@description('Location for the Azure Container Registry')
param location string

@description('Admin username for the Azure Container Registry')
param acrAdminUsername string = 'acrAdmin'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    adminUsername: acrAdminUsername
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
  }
}

// Create ACR token with minimal permissions
resource acrToken 'Microsoft.ContainerRegistry/registries/tokens@2023-07-01' = {
  parent: acr
  name: 'acrPushToken'
  properties: {
    scope: {
      repositories: ['flask-crud-app']
      actions: ['push', 'pull']
    }
    status: 'enabled'
  }
}

// Outputs
output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer 
