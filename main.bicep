// Parameters
@description('Your initials to make resource names unique')
param initials string = 'QDM'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for container registry')
param acrAdminUsername string = 'acrAdmin'

// Variables
var acrName = 'acr${initials}crud'
var vnetName = 'vnet-${initials}-crud'
var subnetName = 'subnet-${initials}-container'
var aciName = 'aci-${initials}-flask-crud'
var logAnalyticsName = 'la-${initials}-crud'

// Container Registry
module acr './modules/acr.bicep' = {
  name: 'acrDeployment'
  params: {
    acrName: acrName
    location: location
    acrAdminUsername: acrAdminUsername
  }
}

// Log Analytics Workspace for monitoring
module logAnalytics './modules/log-analytics.bicep' = {
  name: 'logAnalyticsDeployment'
  params: {
    logAnalyticsName: logAnalyticsName
    location: location
  }
}

// Virtual Network and Subnet
module network './modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    vnetName: vnetName
    subnetName: subnetName
    location: location
  }
}

// Container Instance
module containerInstance './modules/container-instance.bicep' = {
  name: 'containerInstanceDeployment'
  params: {
    aciName: aciName
    location: location
    acrName: acrName
    acrLoginServer: acr.outputs.acrLoginServer
    subnetId: network.outputs.subnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsWorkspaceKey: logAnalytics.outputs.primaryKey
  }
  dependsOn: [
    acr
    network
    logAnalytics
  ]
}

// Outputs
output acrLoginServer string = acr.outputs.acrLoginServer
output containerIPAddress string = containerInstance.outputs.containerIPAddress
output logAnalyticsPortalUrl string = logAnalytics.outputs.portalUrl 
