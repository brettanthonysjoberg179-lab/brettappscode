// Main Bicep template for brettappscode Azure infrastructure
// Creates: ACR, App Service (Linux container), Key Vault, Azure SQL, Storage Account, Application Insights

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Azure Container Registry')
param acrName string

@description('Name of the App Service')
param appServiceName string

@description('Name of the Key Vault')
param keyVaultName string

@description('Name of the SQL Server')
param sqlServerName string

@description('Name of the SQL Database')
param sqlDbName string

@description('Name of Application Insights')
param appInsightsName string

@description('SQL Server admin login')
param sqlAdminLogin string = 'sqladmin'

@secure()
@description('SQL Server admin password')
param sqlAdminPassword string

@description('App Service Plan SKU')
param appServicePlanSku string = 'B1'

@description('Storage Account name')
param storageAccountName string = '${uniqueString(resourceGroup().id)}storage'

// ===== Azure Container Registry =====
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// ===== App Service Plan (Linux) =====
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${appServiceName}-plan'
  location: location
  kind: 'linux'
  sku: {
    name: appServicePlanSku
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// ===== Application Insights =====
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// ===== App Service (Web App for Containers) =====
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
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/brettappscode:latest'
      alwaysOn: true
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acr.properties.loginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acr.listCredentials().username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acr.listCredentials().passwords[0].value
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'PORT'
          value: '3000'
        }
        {
          name: 'NODE_ENV'
          value: 'production'
        }
      ]
    }
  }
}

// ===== Key Vault =====
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    accessPolicies: []
  }
}

// ===== Grant App Service access to Key Vault =====
// Using RBAC: Assign "Key Vault Secrets User" role to App Service managed identity
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appService.id, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ===== Azure SQL Server =====
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
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

// ===== SQL Server Firewall Rule (Allow Azure Services) =====
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ===== Azure SQL Database =====
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
  }
}

// ===== Storage Account =====
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// ===== Outputs =====
output acrLoginServer string = acr.properties.loginServer
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServiceIdentityPrincipalId string = appService.identity.principalId
output keyVaultUri string = keyVault.properties.vaultUri
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output storageAccountName string = storageAccount.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

// NOTES:
// 1. After deployment, store SQL connection string in Key Vault:
//    az keyvault secret set --vault-name <keyVaultName> --name "DatabaseConnectionString" --value "Server=tcp:<sqlServerFqdn>,1433;Database=<sqlDbName>;..."
// 2. Configure App Service to use Key Vault references for sensitive settings
// 3. For production, consider using Private Endpoints for SQL and Storage
// 4. Managed Identity is configured for App Service to access Key Vault (RBAC-based)
