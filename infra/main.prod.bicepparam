using './main.bicep'

// Production environment parameters
param foundryName = 'foundry-prod'
param environment = 'prod'
param enablePrivateEndpoints = true
param vnetAddressPrefix = '10.1.0.0/16'
param foundrySubnetPrefix = '10.1.1.0/24'
param privateEndpointSubnetPrefix = '10.1.2.0/24'
