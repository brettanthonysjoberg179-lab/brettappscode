// Main Bicep template for brettappscode Azure infrastructure
// This template creates all required Azure resources for the application

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Azure Container Registry')
param acrName string

@description('Name of the App Service Plan')
param appServicePlanName string = 'asp-${uniqueString(resourceGroup().id)}'

@description('Name of the App Service (Web App)')
param appServiceName string

@description('Name of the Key Vault')
param keyVaultName string

@description('Name of the SQL Server')
param sqlServerName string

@description('SQL Server admin login')
@secure()
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server admin password')
@secure()
param sqlAdminPassword string

@description('Name of the SQL Database')
param sqlDatabaseName string

@description('Name of the Storage Account')
param storageAccountName string

@description('Name of Application Insights')
param appInsightsName string

@description('Name of Log Analytics Workspace')
param logAnalyticsName string = 'law-${uniqueString(resourceGroup().id)}'

@description('SKU for App Service Plan')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param appServicePlanSku string = 'B1'

@description('SQL Database SKU')
param sqlDatabaseSku string = 'Basic'

// Optional: Uncomment to deploy AKS
// @description('Name of the AKS cluster')
// param aksClusterName string = 'aks-${uniqueString(resourceGroup().id)}'

// @description('AKS node count')
// param aksNodeCount int = 2

// @description('AKS node VM size')
// param aksNodeVmSize string = 'Standard_B2s'

// ============================================
// 1. Container Registry (ACR)
// ============================================
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================
// 2. Log Analytics Workspace
// ============================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ============================================
// 3. Application Insights
// ============================================
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================
// 4. Storage Account
// ============================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// ============================================
// 5. Key Vault
// ============================================
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: false
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    accessPolicies: []
    publicNetworkAccess: 'Enabled'
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// ============================================
// 6. SQL Server
// ============================================
resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// SQL Server Firewall Rule - Allow Azure Services
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-02-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-02-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: sqlDatabaseSku
    tier: sqlDatabaseSku
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2GB
  }
}

// ============================================
// 7. App Service Plan
// ============================================
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: appServicePlanSku
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// ============================================
// 8. App Service (Web App for Containers)
// ============================================
resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|nginx:latest' // Placeholder, will be updated by pipeline
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3000'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.properties.loginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.listCredentials().username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'PORT'
          value: '3000'
        }
        {
          name: 'NODE_ENV'
          value: 'production'
        }
        {
          name: 'KEY_VAULT_NAME'
          value: keyVaultName
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
}

// ============================================
// Optional: 9. Azure Kubernetes Service (AKS)
// Uncomment to deploy AKS
// ============================================
// resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-05-01' = {
//   name: aksClusterName
//   location: location
//   identity: {
//     type: 'SystemAssigned'
//   }
//   properties: {
//     dnsPrefix: '${aksClusterName}-dns'
//     agentPoolProfiles: [
//       {
//         name: 'agentpool'
//         count: aksNodeCount
//         vmSize: aksNodeVmSize
//         osType: 'Linux'
//         mode: 'System'
//       }
//     ]
//     networkProfile: {
//       networkPlugin: 'azure'
//       loadBalancerSku: 'standard'
//     }
//   }
// }

// // Grant AKS pull access to ACR
// resource aksAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: containerRegistry
//   name: guid(containerRegistry.id, aksCluster.id, 'AcrPull')
//   properties: {
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
//     principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
//     principalType: 'ServicePrincipal'
//   }
// }

// ============================================
// Outputs
// ============================================
output acrLoginServer string = containerRegistry.properties.loginServer
output acrName string = containerRegistry.name
output appServiceName string = appService.name
output appServiceDefaultHostName string = appService.properties.defaultHostName
output appServicePrincipalId string = appService.identity.principalId
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
output storageAccountName string = storageAccount.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
// output aksClusterName string = aksCluster.name
// output aksClusterFqdn string = aksCluster.properties.fqdn
