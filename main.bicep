/// About
// This sample assumes a wildcard certificate that can be issued by Let's Encrypt or another CA
// sample command: `certbot certonly --manual -d "*.cloud.XXXX.org"`
// default domain for Application gateway is api-external.cloud.XXXX.org
// default domain for APIM is api-external.cloud.XXXX.org and api-internal.cloud.XXXX.org
// The certificate should be in PFX format with a passwordless private key
//
metadata name = 'Application Gateway to APIM to Azure Function with VNet Integration - Modular'
metadata description = 'Deploys Application Gateway routing to APIM which routes to Azure Function App with secure VNet integration using modular architecture'

var certFilePath = '../../../.ssh/cloud.karpala.pfx'
var certFileBase64 = loadFileAsBase64(certFilePath)
param customDomain string = 'cloud.karpala.org'
param appGtwCustomDomain string = 'api-external.${customDomain}'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Environment suffix')
param environmentName string = 'dev'

@description('Base name for resources')
param baseName string = 'appgw-apim-func'

@description('Your public IP address for secure access to Function App SCM site')
param myIpAddress string = ''

var uniqueSuffix = uniqueString(resourceGroup().id)
var appGwName = '${baseName}-appgw-${uniqueSuffix}'
var appGwPublicIpName = '${baseName}-appgw-pip-${uniqueSuffix}'
var apimName = '${baseName}-apim-${uniqueSuffix}'
var funcAppName = '${baseName}-func-${uniqueSuffix}'
var storageName = take('st${replace(baseName, '-', '')}${uniqueSuffix}', 24)
var appServicePlanName = '${baseName}-plan-${environmentName}'
var deploymentContainerName = 'deploymentpackage'

// identity
module apim_identity 'modules/utils/user-assigned-managed-identity.bicep' = {
  name: 'apim-identity-deployment'
  params: {
    location: location
    name: 'apim-${baseName}-uami-${environmentName}'
  }
}

module funapp_identity 'modules/utils/user-assigned-managed-identity.bicep' = {
  name: 'functionapp-identity-deployment'
  params: {
    location: location
    name: 'function-${baseName}-uami-${environmentName}'
  }
}

module appgtw_identity 'modules/utils/user-assigned-managed-identity.bicep' = {
  name: 'appgateway-identity-deployment'
  params: {
    location: location
    name: 'appgateway-${baseName}-uami-${environmentName}'
  }
}

// Deploy networking resources (VNet, subnets, NSG)
module networking 'modules/networking/vnet.bicep' = {
  name: 'networking-deployment'
  params: {
    location: location
    baseName: baseName
    environmentName: environmentName
  }
}

// Deploy monitoring resources (Log Analytics, App Insights)
module monitoring 'modules/monitoring/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    location: location
    logAnalyticsWorkspaceName: '${baseName}-law-${environmentName}'
    applicationInsightsName: '${baseName}-appi-${environmentName}'
  }
}

module keyVault 'modules/utils/keyvault.bicep' = {
  name: 'key-vault-deployment'
  params: {
    location: location
    name: '${baseName}-kv-${environmentName}'
    userAssignedManagedIdentityPrincipalIds: [
      apim_identity.outputs.AZURE_RESOURCE_USER_ASSIGNED_IDENTITY_PRINCIPAL_ID
      appgtw_identity.outputs.AZURE_RESOURCE_USER_ASSIGNED_IDENTITY_PRINCIPAL_ID
    ]
    logAnalyticsWorkspaceId: monitoring.outputs.AZURE_RESOURCE_MONITORING_LOG_ANALYTICS_ID
    privateEndpointSubnetId: networking.outputs.vmSubnetId
    privateDnsZoneResourceId: dns.outputs.AZURE_RESOURCE_DNS_KEYVAULT_PRIVATE_DNS_ZONE_ID
    secretName: 'apimdomain'
    certFileBase64: certFileBase64
    publicAccessEnabled: true
  }
}

// Deploy storage account
module storage 'modules/storage/storage-account.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    name: storageName
    containerName: deploymentContainerName
    userAssignedManagedIdentityPrincipalId: funapp_identity.outputs.AZURE_RESOURCE_USER_ASSIGNED_IDENTITY_PRINCIPAL_ID
    privateEndpointSubnetId: networking.outputs.vmSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.AZURE_RESOURCE_MONITORING_LOG_ANALYTICS_ID
    blobPrivateDnsZoneResourceId: dns.outputs.AZURE_RESOURCE_DNS_STORAGE_BLOB_PRIVATE_DNS_ZONE_ID
    filePrivateDnsZoneResourceId: dns.outputs.AZURE_RESOURCE_DNS_STORAGE_FILE_PRIVATE_DNS_ZONE_ID
    queuePrivateDnsZoneResourceId: dns.outputs.AZURE_RESOURCE_DNS_STORAGE_QUEUE_PRIVATE_DNS_ZONE_ID
    tablePrivateDnsZoneResourceId: dns.outputs.AZURE_RESOURCE_DNS_STORAGE_TABLE_PRIVATE_DNS_ZONE_ID
  }
}

// Deploy Function App and App Service Plan
module functionApp 'modules/compute/function-app.bicep' = {
  name: 'function-app-deployment'
  params: {
    location: location
    storageAccountName: storageName
    deploymentContainerName: deploymentContainerName
    myIpAddress: myIpAddress
    funcAppName: funcAppName
    managedIdentityId: funapp_identity.outputs.AZURE_RESOURCE_USER_ASSIGNED_IDENTITY_ID
    appServicePlanName: appServicePlanName
    subnetId: networking.outputs.funcSubnetId
    appInsightsConnectionString: monitoring.outputs.AZURE_RESOURCE_MONITORING_APP_INSIGHTS_CONNECTION_STRING
    storageEndpoints: storage.outputs.AZURE_STORAGE_SERVICE_ENDPOINTS
    tags: {
      'azd-service-name': 'function-app'
    }
  }
}

// Deploy API Management
module apim 'modules/apim/apim.bicep' = {
  name: 'apim-deployment'
  params: {
    location: location
    apimName: apimName
    subnetId: networking.outputs.apimSubnetId
    functionAppHostName: functionApp.outputs.functionAppDefaultHostName
    functionAppId: functionApp.outputs.functionAppId
    userAssignedManagedIdentityId: apim_identity.outputs.AZURE_RESOURCE_USER_ASSIGNED_IDENTITY_ID
    certificateResourceId: keyVault.outputs.AZURE_RESOURCE_KEY_VAULT_SECRET_URI
    customDomain: customDomain
  }
}

// Deploy Application Gateway
module appGateway 'modules/gateway/app-gateway.bicep' = {
  name: 'app-gateway-deployment'
  params: {
    location: location
    appGwName: appGwName
    publicIpName: appGwPublicIpName
    subnetId: networking.outputs.appGwSubnetId
    backendFqdn: apim.outputs.apimInternalGatewayUrl
    identityId: appgtw_identity.outputs.AZURE_RESOURCE_USER_ASSIGNED_IDENTITY_ID
    keyVaultCertificateId: keyVault.outputs.AZURE_RESOURCE_KEY_VAULT_SECRET_URI
    customDomain: appGtwCustomDomain
  }
}

module dns 'modules/networking/dns.bicep' = {
  name: 'dns-deployment'
  params: {
    tags: {}
    vnetResourceId: networking.outputs.vnetId
  }
}

module apimDns 'modules/networking/apim-dns.bicep' = {
  name: 'apim-dns-deployment'
  params: {
    vnetResourceId: networking.outputs.vnetId
    apimName: apimName
    apimIpAddress: apim.outputs.apimPrivateIp
  }
}

module apimCustomDns 'modules/networking/apim-dns.bicep' = {
  name: 'apim-custom-dns-deployment'
  params: {
    vnetResourceId: networking.outputs.vnetId
    apimName: 'api'
    apimIpAddress: apim.outputs.apimPrivateIp
    zoneName: customDomain
  }
}

module vmDeployment 'modules/compute/vm.bicep' = {
  name: 'vm-deployment'
  params: {
    location: location
    subnetId: networking.outputs.vmSubnetId
  }
}

// Outputs
output appGwPublicIp string = appGateway.outputs.publicIpAddress
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
output functionAppName string = functionApp.outputs.functionAppName
output functionAppHostName string = functionApp.outputs.functionAppDefaultHostName
output vnetName string = networking.outputs.vnetName
