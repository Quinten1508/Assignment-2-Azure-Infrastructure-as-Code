@description('Name of the Log Analytics Workspace')
param logAnalyticsName string

@description('Location for the Log Analytics Workspace')
param location string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.properties.customerId
output primaryKey string = logAnalyticsWorkspace.listKeys().primarySharedKey
output portalUrl string = 'https://portal.azure.com/#resource${logAnalyticsWorkspace.id}/overview' 
