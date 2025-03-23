@description('Location for all resources')
param location string = resourceGroup().location

@description('Name prefix for all resources')
param namePrefix string = 'qdm'

@description('Container image name')
param imageName string = 'flask-crud'

@description('Container image tag')
param imageTag string = 'latest'

// VNet and Subnet configuration
var vnetName = '${namePrefix}-vnet'
var subnetName = '${namePrefix}-subnet'
var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'

// Network Security Group
var nsgName = '${namePrefix}-nsg'

// ACR configuration
var acrName = '${namePrefix}acr${uniqueString(resourceGroup().id)}'
var acrLoginServer = '${acrName}.azurecr.io'
var acrImageName = '${acrLoginServer}/${imageName}:${imageTag}'

// Container instance configuration
var containerGroupName = '${namePrefix}-container-instance'
var containerName = '${namePrefix}-container'

// Log Analytics workspace
var logAnalyticsWorkspaceName = '${namePrefix}-logs'

// Create Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

// Create VNet and Subnet
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: [
            {
              name: 'DelegationService'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
    ]
  }
}

// Get subnet reference
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: subnetName
  parent: vnet
}

// Create Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Create Container Instance
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  properties: {
    containers: [
      {
        name: containerName
        properties: {
          image: acrImageName
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
    }
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: acr.listCredentials().username
        password: acr.listCredentials().passwords[0].value
      }
    ]
    diagnostics: {
      logAnalytics: {
        workspaceId: logAnalyticsWorkspace.properties.customerId
        workspaceKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    subnetIds: [
      {
        id: subnet.id
      }
    ]
  }
}

// Outputs
output acrLoginServer string = acrLoginServer
output containerIPAddress string = containerGroup.properties.ipAddress.ip 
