// Application Gateway Module

@description('Azure region for the Application Gateway')
param location string

@description('Name of the Application Gateway')
param appGatewayName string

@description('Private IP address of the backend container')
param backendIpAddress string

@description('ID of the subnet to deploy the Application Gateway to')
param appGatewaySubnetId string

@description('Frontend port for HTTP')
param frontendPort int = 80

@description('Frontend port for HTTPS')
param httpsPort int = 443

@description('Enable HTTPS')
param enableHttps bool = false

@description('SSL certificate data in Base64 format')
param sslCertificateData string = ''

@description('SSL certificate password')
@secure()
param sslCertificatePassword string = ''

@description('Host name for the HTTPS listener')
param httpsHostName string = ''

// Create the public IP for the Application Gateway
resource publicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${appGatewayName}-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${appGatewayName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// Create the Application Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: appGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGatewayFrontendPort'
        properties: {
          port: frontendPort
        }
      }
      // Add HTTPS port if enabled
      {
        name: 'httpsPort'
        properties: {
          port: httpsPort
        }
      }
    ]
    // Add SSL certificate if HTTPS is enabled
    sslCertificates: enableHttps ? [
      {
        name: 'iacCertificate'
        properties: {
          data: sslCertificateData
          password: sslCertificatePassword
        }
      }
    ] : []
    backendAddressPools: [
      {
        name: 'flaskCrudBackendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: backendIpAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'flaskCrudHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'flaskCrudHealthProbe')
          }
        }
      }
    ]
    httpListeners: concat([
      {
        name: 'flaskCrudListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'appGatewayFrontendPort')
          }
          protocol: 'Http'
        }
      }
    ], enableHttps ? [
      {
        name: 'httpsListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'httpsPort')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'iacCertificate')
          }
          hostName: httpsHostName
          requireServerNameIndication: !empty(httpsHostName)
        }
      }
    ] : [])
    requestRoutingRules: concat([
      {
        name: 'flaskCrudRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'flaskCrudListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'flaskCrudBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'flaskCrudHttpSettings')
          }
          priority: 100
        }
      }
    ], enableHttps ? [
      {
        name: 'httpsRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpsListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'flaskCrudBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'flaskCrudHttpSettings')
          }
          priority: 200
        }
      }
    ] : [])
    probes: [
      {
        name: 'flaskCrudHealthProbe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
  }
}

// Outputs
output appGatewayId string = appGateway.id
output appGatewayFQDN string = publicIP.properties.dnsSettings.fqdn
output appGatewayPublicIp string = publicIP.properties.ipAddress 
