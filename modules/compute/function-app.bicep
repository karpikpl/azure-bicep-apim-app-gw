@description('Azure region for resources')
param location string = resourceGroup().location

@description('Function App name')
param funcAppName string

@description('App Service Plan name')
param appServicePlanName string

@description('Subnet ID for VNet integration')
param subnetId string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Storage account endpoints')
param storageEndpoints object

param storageAccountName string
param deploymentContainerName string

param managedIdentityId string

param myIpAddress string = ''

param tags object = {}

// split managed identity resource ID to get the name
var identityParts = split(managedIdentityId, '/')
// get the name of the managed identity
var managedIdentityName = length(identityParts) > 0 ? identityParts[length(identityParts) - 1] : ''

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

// App Service Plan - Flex Consumption
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: funcAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: subnetId
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageEndpoints.blob}${deploymentContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identity.id
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 512
        maximumInstanceCount: 40
      }
      runtime: {
        name: 'python'
        version: '3.11'
      }
    }
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmIpSecurityRestrictions: empty(myIpAddress) ? [] : [
        {
          ipAddress: '${myIpAddress}/32'
          action: 'Allow'
          priority: 100
          description: 'Allow my IP'
        }
      ]
      vnetRouteAllEnabled: true
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      appSettings: [

        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: identity.properties.clientId
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: identity.properties.clientId
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ]
    }
  }
}

output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.?principalId ?? identity.properties.principalId
output functionAppDefaultHostName string = functionApp.properties.defaultHostName
output appServicePlanId string = appServicePlan.id
