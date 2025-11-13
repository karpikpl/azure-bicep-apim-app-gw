@description('Storage account resource ID')
param storageAccountId string

@description('Function App principal ID')
param functionAppPrincipalId string

// Role Assignment: Storage Blob Data Owner for Function App
resource storageBlobDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, functionAppPrincipalId, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    ) // Storage Blob Data Owner
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment: Storage Queue Data Contributor for Function App
resource storageQueueDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, functionAppPrincipalId, '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
    ) // Storage Queue Data Contributor
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment: Storage Table Data Contributor for Function App
resource storageTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, functionAppPrincipalId, '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
    ) // Storage Table Data Contributor
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}
