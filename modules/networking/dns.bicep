param tags object = {}
param vnetResourceId string

var vnetLinks = empty(vnetResourceId)
  ? []
  : [
      {
        virtualNetworkResourceId: vnetResourceId
      }
    ]

module kvDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'keyvault-privateDnsZoneDeployment'
  params: {
    tags: tags
    // Required parameters
    name: 'privatelink.vaultcore.azure.net'
    // Non-required parameters
    location: 'global'
    virtualNetworkLinks: vnetLinks
  }
}


module storageBlobDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'storageBlob-privateDnsZoneDeployment'
  params: {
    tags: tags
    // Required parameters
    name: 'privatelink.blob.${environment().suffixes.storage}'
    // Non-required parameters
    location: 'global'
    virtualNetworkLinks: vnetLinks
  }
}

module storageQueueDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'storageQueue-privateDnsZoneDeployment'
  params: {
    tags: tags
    // Required parameters
    name: 'privatelink.queue.${environment().suffixes.storage}'
    // Non-required parameters
    location: 'global'
    virtualNetworkLinks: vnetLinks
  }
}

module storageTableDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'storageTable-privateDnsZoneDeployment'
  params: {
    tags: tags
    // Required parameters
    name: 'privatelink.table.${environment().suffixes.storage}'
    // Non-required parameters
    location: 'global'
    virtualNetworkLinks: vnetLinks
  }
}

module storageFileDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'storageFile-privateDnsZoneDeployment'
  params: {
    tags: tags
    // Required parameters
    name: 'privatelink.file.${environment().suffixes.storage}'
    // Non-required parameters
    location: 'global'
    virtualNetworkLinks: vnetLinks
  }
}

output AZURE_RESOURCE_DNS_KEYVAULT_PRIVATE_DNS_ZONE_ID string = kvDnsZone.outputs.resourceId
output AZURE_RESOURCE_DNS_STORAGE_BLOB_PRIVATE_DNS_ZONE_ID string = storageBlobDnsZone.outputs.resourceId
output AZURE_RESOURCE_DNS_STORAGE_QUEUE_PRIVATE_DNS_ZONE_ID string = storageQueueDnsZone.outputs.resourceId
output AZURE_RESOURCE_DNS_STORAGE_TABLE_PRIVATE_DNS_ZONE_ID string = storageTableDnsZone.outputs.resourceId
output AZURE_RESOURCE_DNS_STORAGE_FILE_PRIVATE_DNS_ZONE_ID string = storageFileDnsZone.outputs.resourceId
