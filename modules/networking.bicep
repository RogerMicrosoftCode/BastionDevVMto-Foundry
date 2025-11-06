// Networking module for Azure AI Foundry
targetScope = 'resourceGroup'

@description('Location for all resources')
param location string

@description('Name of the virtual network')
param vnetName string

@description('Virtual Network address prefix')
param vnetAddressPrefix string

@description('Subnet address prefix for AI Foundry')
param foundrySubnetPrefix string

@description('Subnet address prefix for private endpoints')
param privateEndpointSubnetPrefix string

@description('Tags to apply to resources')
param tags object

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-foundry'
        properties: {
          addressPrefix: foundrySubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.CognitiveServices'
            }
          ]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// Network Security Group for Foundry subnet
resource nsgFoundry 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${vnetName}-foundry-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Network Security Group for Private Endpoints subnet
resource nsgPrivateEndpoints 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${vnetName}-pe-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// Associate NSG with subnets
resource foundrySubnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  parent: vnet
  name: 'snet-foundry'
  properties: {
    addressPrefix: foundrySubnetPrefix
    networkSecurityGroup: {
      id: nsgFoundry.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.CognitiveServices'
      }
    ]
  }
}

resource privateEndpointSubnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  parent: vnet
  name: 'snet-private-endpoints'
  properties: {
    addressPrefix: privateEndpointSubnetPrefix
    networkSecurityGroup: {
      id: nsgPrivateEndpoints.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    foundrySubnetNsgAssociation
  ]
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output foundrySubnetId string = foundrySubnetNsgAssociation.id
output privateEndpointSubnetId string = privateEndpointSubnetNsgAssociation.id
