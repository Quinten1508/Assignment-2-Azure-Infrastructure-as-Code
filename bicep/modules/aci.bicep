// Azure Container Instance Module

@description('Azure region for the Container Instance')
param location string

@description('Name of the Container Group')
param containerGroupName string

@description('Container image name with tag')
param containerImageName string

@description('ID of the subnet to deploy the container instance to')
param subnetId string

@description('Name of the Azure Container Registry')
param acrName string

@description('Login server of the Azure Container Registry')
param acrLoginServer string

@description('Log Analytics Workspace ID for container monitoring')
param logAnalyticsWorkspaceId string

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

@description('CPU cores for the container instance')
param cpuCores int = 1

@description('Memory in GB for the container instance')
param memoryInGb int = 1

@description('Port for the container')
param port int = 80

// Get the ACR credentials
resource acrResource 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: acrName
}

// Reference to Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

// Create Container Group
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: containerGroupName
  location: location
  properties: {
    containers: [
      {
        name: 'flask-crud-container'
        properties: {
          image: containerImageName
          ports: [
            {
              port: port
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Always'
    subnetIds: [
      {
        id: subnetId
      }
    ]
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: acrResource.listCredentials().username
        password: acrResource.listCredentials().passwords[0].value
      }
    ]
    diagnostics: {
      logAnalytics: {
        workspaceId: logAnalyticsWorkspaceId
        workspaceKey: listKeys(logAnalyticsWorkspace.id, logAnalyticsWorkspace.apiVersion).primarySharedKey
      }
    }
    ipAddress: {
      type: 'Private'
      ports: [
        {
          port: port
          protocol: 'TCP'
        }
      ]
    }
  }
}

// Outputs
output containerGroupId string = containerGroup.id
output containerIPv4Address string = containerGroup.properties.ipAddress.ip 
