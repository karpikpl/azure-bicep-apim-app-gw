@description('Azure region for resources')
param location string = resourceGroup().location

@description('Base name for resources')
param baseName string

@description('Environment suffix')
param environmentName string

@description('Virtual network address space')
param vnetAddressSpace string = '10.1.0.0/16'

@description('Application Gateway subnet address prefix')
param appGwSubnetAddressPrefix string = '10.1.0.0/24'

@description('APIM subnet address prefix')
param apimSubnetAddressPrefix string = '10.1.1.0/24'

@description('Function subnet address prefix')
param funcSubnetAddressPrefix string = '10.1.2.0/24'

param vmSubnetAddressPrefix string = '10.1.3.0/24'

var vnetName = '${baseName}-vnet-${environmentName}'
var appGwSubnetName = 'appgw-subnet'
var apimSubnetName = 'apim-subnet'
var funcSubnetName = 'function-subnet'
var vmSubnetName = 'vm-subnet'

// Network Security Group module for APIM
module nsgModule 'nsg.bicep' = {
  name: 'nsg-deployment'
  params: {
    location: location
    baseName: baseName
    environmentName: environmentName
  }
}

module defaultNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: 'default-network-security-group'
  params: {
    name: 'default-nsg'
    location: location
    securityRules: []
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressSpace]
    }
    subnets: [
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGwSubnetAddressPrefix
        }
      }
      {
        name: apimSubnetName
        properties: {
          addressPrefix: apimSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgModule.outputs.nsgId
          }
          serviceEndpoints: [
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.Web' }
            { service: 'Microsoft.KeyVault' }
          ]
        }
      }
      {
        name: funcSubnetName
        properties: {
          addressPrefix: funcSubnetAddressPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          serviceEndpoints: [
            { service: 'Microsoft.Storage' }
          ]
        }
      }
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetAddressPrefix
          networkSecurityGroup: {
            id: defaultNetworkSecurityGroup.outputs.resourceId
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output appGwSubnetId string = '${vnet.id}/subnets/${appGwSubnetName}'
output apimSubnetId string = '${vnet.id}/subnets/${apimSubnetName}'
output funcSubnetId string = '${vnet.id}/subnets/${funcSubnetName}'
output vmSubnetId string = '${vnet.id}/subnets/${vmSubnetName}'
output appGwSubnetName string = appGwSubnetName
output apimSubnetName string = apimSubnetName
output funcSubnetName string = funcSubnetName
output vmSubnetName string = vmSubnetName
