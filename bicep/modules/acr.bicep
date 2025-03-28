// Azure Container Registry Module

@description('Azure region for the ACR')
param location string

@description('Name of the Azure Container Registry')
param acrName string

@description('SKU of the Azure Container Registry')
param acrSku string = 'Basic'

// Create Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

// Outputs
output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name 
