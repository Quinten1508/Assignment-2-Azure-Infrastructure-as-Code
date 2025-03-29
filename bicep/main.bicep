// Azure Infrastructure-as-Code Assignment
// Main Bicep file for deploying a Flask CRUD application to Azure Container Instances

// Parameters
@description('Your unique initials for resource naming')
param initials string

@description('Azure region to deploy resources')
param location string = resourceGroup().location

@description('The name of the ACR (must be globally unique)')
param acrName string = 'acr${toLower(initials)}crud'

@description('The name of the container instance')
param containerGroupName string = 'aci-${toLower(initials)}-flask-crud'

@description('The name of the virtual network')
param vnetName string = 'vnet-${initials}-crud'

@description('The name of the subnet for container instance')
param subnetName string = 'subnet-${initials}-aci'

@description('The name of the network security group')
param nsgName string = '${subnetName}-nsg'

@description('The name of the network security group for the App Gateway')
param appGwNsgName string = 'appgw-${initials}-nsg'

@description('The name of Log Analytics workspace')
param logAnalyticsName string = 'la-${initials}-crud'

@description('The name of the Application Gateway')
param appGatewayName string = 'appgw-${initials}-flask'

@description('Container image name')
param containerImageName string = '${acrName}.azurecr.io/flask-crud:latest'

@description('ACR token name with pull permissions')
param acrTokenName string = 'acrpull-token'

// SSL Configuration parameters
@description('Enable HTTPS on the Application Gateway')
param enableHttps bool = false

@description('SSL certificate data in Base64 format for HTTPS')
param sslCertificateData string = ''

@description('SSL certificate password')
@secure()
param sslCertificatePassword string = ''

@description('Host name for HTTPS listener (e.g., iac.quinten-de-meyer.be)')
param httpsHostName string = ''

// Network Security Group for Container Subnet
module nsgModule 'modules/nsg.bicep' = {
  name: 'nsgDeployment'
  params: {
    location: location
    nsgName: nsgName
  }
}

// Network Security Group for Application Gateway
module appGwNsgModule 'modules/nsg-appgw.bicep' = {
  name: 'appGwNsgDeployment'
  params: {
    location: location
    nsgName: appGwNsgName
  }
}

// Virtual Network with Subnet
module vnetModule 'modules/vnet.bicep' = {
  name: 'vnetDeployment'
  params: {
    location: location
    vnetName: vnetName
    subnetName: subnetName
    nsgId: nsgModule.outputs.nsgId
    appGatewayNsgId: appGwNsgModule.outputs.nsgId
  }
}

// Azure Container Registry
module acrModule 'modules/acr.bicep' = {
  name: 'acrDeployment'
  params: {
    location: location
    acrName: acrName
  }
}

// ACR Token with pull permissions
module acrTokenModule 'modules/acr-token.bicep' = {
  name: 'acrTokenDeployment'
  params: {
    acrName: acrName
    tokenName: acrTokenName
  }
  dependsOn: [
    acrModule
  ]
}

// Log Analytics Workspace
module logAnalyticsModule 'modules/loganalytics.bicep' = {
  name: 'logAnalyticsDeployment'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
  }
}

// Azure Container Instance
module aciModule 'modules/aci.bicep' = {
  name: 'aciDeployment'
  params: {
    location: location
    containerGroupName: containerGroupName
    containerImageName: containerImageName
    subnetId: vnetModule.outputs.subnetId
    acrName: acrName
    acrLoginServer: acrModule.outputs.acrLoginServer
    logAnalyticsWorkspaceId: logAnalyticsModule.outputs.workspaceId
    logAnalyticsWorkspaceName: logAnalyticsName
  }
}

// Application Gateway
module appGatewayModule 'modules/appgateway.bicep' = {
  name: 'appGatewayDeployment'
  params: {
    location: location
    appGatewayName: appGatewayName
    backendIpAddress: aciModule.outputs.containerIPv4Address
    appGatewaySubnetId: vnetModule.outputs.appGatewaySubnetId
    enableHttps: enableHttps
    sslCertificateData: sslCertificateData
    sslCertificatePassword: sslCertificatePassword
    httpsHostName: httpsHostName
  }
}

// Outputs
output acrLoginServer string = acrModule.outputs.acrLoginServer
output containerIPv4Address string = aciModule.outputs.containerIPv4Address
output appGatewayPublicIp string = appGatewayModule.outputs.appGatewayPublicIp
output appGatewayFQDN string = appGatewayModule.outputs.appGatewayFQDN 
