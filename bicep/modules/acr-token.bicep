// ACR Token Module

@description('Name of the Azure Container Registry')
param acrName string

@description('Name of the token')
param tokenName string = 'acrpull-token'

@description('Name of the scope map')
param scopeMapName string = 'pull-scope-map'

// Create a scope map for pull access only
resource pullScopeMap 'Microsoft.ContainerRegistry/registries/scopeMaps@2023-07-01' = {
  name: '${acrName}/${scopeMapName}'
  properties: {
    actions: [
      'repositories/flask-crud/content/read'
    ]
    description: 'Pull access for flask-crud repository'
  }
}

// Create a token with the scope map
resource acrToken 'Microsoft.ContainerRegistry/registries/tokens@2023-07-01' = {
  name: '${acrName}/${tokenName}'
  properties: {
    scopeMapId: pullScopeMap.id
    status: 'enabled'
  }
  dependsOn: [
    pullScopeMap
  ]
}

// Outputs
output tokenName string = acrToken.name
output scopeMapName string = pullScopeMap.name 
