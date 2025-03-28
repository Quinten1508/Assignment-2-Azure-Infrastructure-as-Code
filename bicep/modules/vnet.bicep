// Virtual Network Module

@description('Azure region for the VNet')
param location string

@description('Name of the Virtual Network')
param vnetName string

@description('Name of the Subnet')
param subnetName string

@description('Name of the Application Gateway Subnet')
param appGatewaySubnetName string = 'subnet-appgw'

@description('ID of the Network Security Group to associate with the container subnet')
param nsgId string

@description('ID of the Network Security Group to associate with the App Gateway subnet')
param appGatewayNsgId string

// Create Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsgId
          }
          delegations: [
            {
              name: 'acidelegation'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
      {
        name: appGatewaySubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: appGatewayNsgId
          }
        }
      }
    ]
  }
}

// Get subnet resource reference
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${vnetName}/${subnetName}'
  dependsOn: [
    vnet
  ]
}

// Get Application Gateway subnet resource reference
resource appGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${vnetName}/${appGatewaySubnetName}'
  dependsOn: [
    vnet
  ]
}

// Outputs
output vnetId string = vnet.id
output subnetId string = subnet.id
output appGatewaySubnetId string = appGatewaySubnet.id 
