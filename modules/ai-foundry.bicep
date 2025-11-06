// AI Foundry Hub module
targetScope = 'resourceGroup'

@description('Location for all resources')
param location string

@description('Name of the AI Foundry Hub')
param foundryName string

@description('Storage Account resource ID')
param storageAccountId string

@description('Key Vault resource ID')
param keyVaultId string

@description('Subnet ID for the AI Foundry (if using private networking)')
param subnetId string

@description('Tags to apply to resources')
param tags object

// Cognitive Services Account (AI Services)
resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: '${foundryName}-ai-services'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: '${foundryName}-ai-services'
    publicNetworkAccess: !empty(subnetId) ? 'Disabled' : 'Enabled'
    networkAcls: !empty(subnetId) ? {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    } : {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Machine Learning Workspace (AI Foundry Hub)
resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: foundryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: foundryName
    description: 'Azure AI Foundry Hub migrated from Bastion DevVM'
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: appInsights.id
    publicNetworkAccess: !empty(subnetId) ? 'Disabled' : 'Enabled'
    managedNetwork: !empty(subnetId) ? {
      isolationMode: 'AllowOnlyApprovedOutbound'
    } : {
      isolationMode: 'Disabled'
    }
  }
  kind: 'Hub'
}

// Log Analytics Workspace for Application Insights
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${foundryName}-logs'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights for monitoring (linked to Log Analytics)
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${foundryName}-insights'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Reference existing storage account for RBAC
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: last(split(storageAccountId, '/'))
}

// RBAC: Grant AI Services access to Storage
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccountId, cognitiveServices.id, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: cognitiveServices.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// RBAC: Grant ML Workspace access to Storage
resource mlStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccountId, mlWorkspace.id, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: mlWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output foundryId string = mlWorkspace.id
output foundryName string = mlWorkspace.name
output foundryEndpoint string = mlWorkspace.properties.discoveryUrl
output cognitiveServicesId string = cognitiveServices.id
output cognitiveServicesEndpoint string = cognitiveServices.properties.endpoint
output appInsightsId string = appInsights.id
