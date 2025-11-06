using './main.bicep'

// Development environment parameters
param foundryName = 'foundry-dev'
param environment = 'dev'
param enablePrivateEndpoints = false
param vnetAddressPrefix = '10.0.0.0/16'
param foundrySubnetPrefix = '10.0.1.0/24'
param privateEndpointSubnetPrefix = '10.0.2.0/24'
