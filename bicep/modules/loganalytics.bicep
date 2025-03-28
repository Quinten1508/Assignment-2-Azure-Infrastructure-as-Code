// Log Analytics Workspace Module

@description('Azure region for the Log Analytics Workspace')
param location string

@description('Name of the Log Analytics Workspace')
param logAnalyticsName string

@description('The SKU of the Log Analytics Workspace')
param sku string = 'PerGB2018'

@description('The retention period for the logs in days')
param retentionInDays int = 30

// Create Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.properties.customerId
