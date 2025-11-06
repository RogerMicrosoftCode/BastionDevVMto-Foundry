// Main orchestrator template for Azure AI Foundry migration
targetScope = 'resourceGroup'

@description('Name of the AI Foundry resource')
param foundryName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Enable private endpoints for secure networking')
param enablePrivateEndpoints bool = false

@description('Virtual Network address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix for AI Foundry')
param foundrySubnetPrefix string = '10.0.1.0/24'

@description('Subnet address prefix for private endpoints')
param privateEndpointSubnetPrefix string = '10.0.2.0/24'

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  ManagedBy: 'Bicep'
  Project: 'BastionDevVM-to-Foundry'
}

// Module: Virtual Network
module vnet '../modules/networking.bicep' = {
  name: 'vnet-deployment'
  params: {
    location: location
    vnetName: 'vnet-${foundryName}-${environment}'
    vnetAddressPrefix: vnetAddressPrefix
    foundrySubnetPrefix: foundrySubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    tags: tags
  }
}

// Module: Storage Account
module storage '../modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountName: 'st${uniqueString(resourceGroup().id)}${environment}'
    enablePrivateEndpoint: enablePrivateEndpoints
    subnetId: enablePrivateEndpoints ? vnet.outputs.privateEndpointSubnetId : ''
    tags: tags
  }
}

// Module: Key Vault
module keyVault '../modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    location: location
    keyVaultName: 'kv-${uniqueString(resourceGroup().id)}-${environment}'
    enablePrivateEndpoint: enablePrivateEndpoints
    subnetId: enablePrivateEndpoints ? vnet.outputs.privateEndpointSubnetId : ''
    tags: tags
  }
}

// Module: AI Foundry Hub
module aiFoundry '../modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  params: {
    location: location
    foundryName: foundryName
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    subnetId: enablePrivateEndpoints ? vnet.outputs.foundrySubnetId : ''
    tags: tags
  }
}

// Outputs
output foundryId string = aiFoundry.outputs.foundryId
output foundryEndpoint string = aiFoundry.outputs.foundryEndpoint
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultName string = keyVault.outputs.keyVaultName
output vnetId string = vnet.outputs.vnetId
