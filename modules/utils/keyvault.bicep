param location string
param name string
param secretName string
param tags object = {}
param userAssignedManagedIdentityPrincipalIds string[]
param principalId string?
param doRoleAssignments bool = true
param logAnalyticsWorkspaceId string
param privateEndpointSubnetId string?
param privateEndpointName string = '${name}-pe'
param privateDnsZoneResourceId string = ''
@description('If true, the key vault will allow public access. Not recommended for production scenarios.')
param publicAccessEnabled bool = false
param certFileBase64 string

var secretsUserAssignments = [
  for principalIdItem in userAssignedManagedIdentityPrincipalIds: {
    principalId: principalIdItem
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Key Vault Secrets User'
  }
]

var readerAssignments = [
  for principalIdItem in userAssignedManagedIdentityPrincipalIds: {
    principalId: principalIdItem
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Key Vault Reader'
  }
]

var peAssignments = [
  for principalIdItem in userAssignedManagedIdentityPrincipalIds: {
    principalId: principalIdItem
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Reader'
  }
]

module vault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: 'vault-${name}'
  params: {
    name: name
    location: location
    diagnosticSettings: [
      {
        name: 'all-logs-to-log-analytics'
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: publicAccessEnabled ? 'Allow' : 'Deny'
    }
    publicNetworkAccess: publicAccessEnabled ? 'Enabled' : 'Disabled'
    roleAssignments: doRoleAssignments
      ? union(
          secretsUserAssignments,
          readerAssignments,
          empty(principalId)
            ? []
            : [
                {
                  principalId: principalId
                  principalType: 'User'
                  roleDefinitionIdOrName: 'Key Vault Secrets Officer'
                }
              ]
        )
      : []
    privateEndpoints: empty(privateEndpointSubnetId)
      ? null
      : [
          {
            name: privateEndpointName
            subnetResourceId: privateEndpointSubnetId!
            tags: tags
            privateDnsZoneGroup: empty(privateDnsZoneResourceId)
              ? null
              : {
                  privateDnsZoneGroupConfigs: [
                    { privateDnsZoneResourceId: privateDnsZoneResourceId }
                  ]
                }
            roleAssignments: peAssignments
          }
        ]
    secrets: [
      {
        name: secretName
        contentType: 'application/x-pkcs12'
        value: certFileBase64
      }
    ]

    enablePurgeProtection: false
    enableRbacAuthorization: true
    tags: tags
  }
}

output AZURE_RESOURCE_KEY_VAULT_ID string = vault.outputs.resourceId
output AZURE_RESOURCE_KEY_VAULT_NAME string = vault.outputs.name
output AZURE_RESOURCE_KEY_VAULT_SECRET_URI string = vault.outputs.secrets[0].uri
