@description('Azure region for resources')
param location string = resourceGroup().location

@description('Storage account name')
param storageName string

@description('Virtual network rules for storage account')
param virtualNetworkRules array = []

@description('Network access rules default action')
param networkDefaultAction string = 'Deny'

// Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkDefaultAction
      virtualNetworkRules: virtualNetworkRules
    }
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

output storageId string = storage.id
output storageName string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints
