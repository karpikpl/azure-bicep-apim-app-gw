@description('Azure region for resources')
param location string = resourceGroup().location

@description('APIM service name')
param apimName string

@description('Subnet ID for APIM deployment')
param subnetId string

@description('Function App hostname for backend configuration')
param functionAppHostName string

@description('Function App resource ID')
param functionAppId string

param userAssignedManagedIdentityId string
param certificateResourceId string = ''
param customDomain string = ''

// split managed identity resource ID to get the name
var identityParts = split(userAssignedManagedIdentityId, '/')
// get the name of the managed identity
var managedIdentityName = length(identityParts) > 0 ? identityParts[length(identityParts) - 1] : ''

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

// API Management
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedManagedIdentityId}': {}
    }
  }
  properties: {
    publisherEmail: 'admin@example.com'
    publisherName: 'API Publisher'
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
    hostnameConfigurations: [
      {
        type: 'Management'
        hostName: 'management.${customDomain}'
        certificateSource: 'KeyVault'
        keyVaultId: certificateResourceId
        identityClientId: identity.properties.clientId
      }
      {
        type: 'Portal'
        hostName: 'portal.${customDomain}'
        certificateSource: 'KeyVault'
        keyVaultId: certificateResourceId
        identityClientId: identity.properties.clientId
      }
      {
        type: 'Proxy'
        hostName: 'api.${customDomain}'
        certificateSource: 'KeyVault'
        keyVaultId: certificateResourceId
        identityClientId: identity.properties.clientId
      }
      {
        type: 'Proxy'
        hostName: 'api-internal.${customDomain}'
        certificateSource: 'KeyVault'
        keyVaultId: certificateResourceId
        identityClientId: identity.properties.clientId
      }
      {
        type: 'Scm'
        hostName: 'scm.${customDomain}'
        certificateSource: 'KeyVault'
        keyVaultId: certificateResourceId
        identityClientId: identity.properties.clientId
      }
    ]
  }
}

// APIM Backend for Function App
resource apimBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'function-backend'
  properties: {
    description: 'Azure Function Backend'
    url: 'https://${functionAppHostName}/api'
    protocol: 'http'
    resourceId: '${environment().resourceManager}${functionAppId}'
  }
}

// APIM API
resource apimApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'func-api'
  properties: {
    displayName: 'Function API'
    path: 'func-test'
    protocols: ['https']
    subscriptionRequired: true
  }
}

// APIM API Operation
resource apimPostOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: apimApi
  name: 'func-test-post'
  properties: {
    displayName: 'Function Test POST'
    method: 'POST'
    urlTemplate: '/'
  }
}

resource apimGetOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: apimApi
  name: 'func-test-get'
  properties: {
    displayName: 'Function Test GET'
    method: 'GET'
    urlTemplate: '/'
  }
}

// APIM API Policy
resource apimApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: apimApi
  name: 'policy'
  properties: {
    value: '''
      <policies>
        <inbound>
          <base />
          <set-backend-service backend-id="function-backend" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
        </outbound>
        <on-error>
          <base />
        </on-error>
      </policies>
    '''
    format: 'xml'
  }
  dependsOn: [apimBackend]
}

output apimId string = apim.id
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimPrivateIp string = apim.properties.privateIPAddresses != null && length(apim.properties.privateIPAddresses) > 0
  ? apim.properties.privateIPAddresses[0]
  : ''
output apimInternalGatewayUrl string = apim.properties.gatewayUrl != null
  ? replace(apim.properties.gatewayUrl, 'https://', '')
  : '${apim.name}.azure-api.net'
