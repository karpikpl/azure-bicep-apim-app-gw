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

var functionHostKey = listkeys('${functionAppId}/host/default', '2024-11-01').functionKeys.default

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
        hostName: 'api-external.${customDomain}'
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

resource namedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: 'functionapp-key'
  parent: apim
  properties: {
    displayName: 'functionapp-key'
    value: functionHostKey
    secret: true
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
    credentials: {
      header: {
        'x-functions-key': ['{{${namedValue.name}}}']
      }
    }
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

resource externalTag 'Microsoft.ApiManagement/service/tags@2024-10-01-preview' = {
  parent: apim
  name: 'external'
  properties: {
    displayName: 'External'
  }
}

resource externalTagApiLinks 'Microsoft.ApiManagement/service/tags/apiLinks@2024-10-01-preview' = {
  parent: externalTag
  name: 'external-tag-api-link'
  properties: {
    apiId: apimDummyApi.id
  }
}

resource apimDummyApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'dummy-api'
  properties: {
    displayName: 'External Dummy API'
    path: 'external/dummy-api'
    protocols: ['https']
    subscriptionRequired: true
  }
}

// APIM API Operation
resource dummyPostOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: apimDummyApi
  name: 'dummy-post'
  properties: {
    displayName: 'Dummy POST'
    method: 'POST'
    urlTemplate: '/'
  }
}

resource dummyGetOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: apimDummyApi
  name: 'dummy-get'
  properties: {
    displayName: 'Dummy GET'
    method: 'GET'
    urlTemplate: '/'
  }
}

// APIM API Operation
resource apimPostOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: apimApi
  name: 'func-test-post'
  properties: {
    displayName: 'Function Test POST'
    method: 'POST'
    urlTemplate: '/echo'
  }
}

resource apimGetOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: apimApi
  name: 'func-test-get'
  properties: {
    displayName: 'Function Test GET'
    method: 'GET'
    urlTemplate: '/echo'
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

// APIM API Policy
resource apimDummyPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: apimDummyApi
  name: 'policy'
  properties: {
    value: '''
  <policies>
      <!-- Throttle, authorize, validate, cache, or transform the requests -->
      <inbound>
          <return-response>
              <set-status code="200" reason="OK" />
              <set-header name="X-MY-API" exists-action="override">
                  <value>20</value>
              </set-header>
              <set-body>This is a response from External API</set-body>
          </return-response>
          <base />
      </inbound>
      <!-- Control if and how the requests are forwarded to services  -->
      <backend>
          <base />
      </backend>
      <!-- Customize the responses -->
      <outbound>
          <base />
      </outbound>
      <!-- Handle exceptions and customize error responses  -->
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
