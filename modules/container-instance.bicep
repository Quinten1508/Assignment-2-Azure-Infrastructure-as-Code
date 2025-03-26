@description('Name of the Container Instance')
param aciName string

@description('Location for the resources')
param location string

@description('ACR name')
param acrName string

@description('ACR login server')
param acrLoginServer string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics Workspace primary key')
param logAnalyticsWorkspaceKey string

@description('Subnet ID for container instance')
param subnetId string

@description('Container image name')
param containerImageName string = 'flask-crud-app:latest'

@description('CPU cores for the container')
param cpuCores int = 1

@description('Memory in GB for the container')
param memoryInGb int = 2

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: aciName
  location: location
  properties: {
    sku: 'Standard'
    containers: [
      {
        name: 'flask-crud-app'
        properties: {
          image: '${acrLoginServer}/${containerImageName}'
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          environmentVariables: [
            {
              name: 'FLASK_APP'
              value: 'crudapp.py'
            }
            {
              name: 'PYTHONUNBUFFERED'
              value: '1'
            }
          ]
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
      dnsNameLabel: toLower('flask-${aciName}')
    }
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: 'acrAdmin'
        password: listCredentials(resourceId('Microsoft.ContainerRegistry/registries', acrName), '2023-07-01').passwords[0].value
      }
    ]
    diagnostics: {
      logAnalytics: {
        workspaceId: logAnalyticsWorkspaceId
        workspaceKey: logAnalyticsWorkspaceKey
        logType: 'ContainerInsights'
      }
    }
  }
}

// Outputs
output containerIPAddress string = containerGroup.properties.ipAddress.ip
output containerFqdn string = containerGroup.properties.ipAddress.fqdn
output containerState string = containerGroup.properties.instanceView.state 
