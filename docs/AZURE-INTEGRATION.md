# Azure Integration Guide for brettappscode

This guide provides comprehensive instructions for deploying and running the brettappscode application on Azure using Azure Pipelines, Infrastructure as Code (IaC), and Azure platform services.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Azure Resources Required](#azure-resources-required)
4. [Service Principal Setup](#service-principal-setup)
5. [Azure DevOps Setup](#azure-devops-setup)
6. [Pipeline Variables Configuration](#pipeline-variables-configuration)
7. [Infrastructure Deployment](#infrastructure-deployment)
8. [Pipeline Execution](#pipeline-execution)
9. [Post-Deployment Configuration](#post-deployment-configuration)
10. [Azure AD Authentication](#azure-ad-authentication)
11. [Key Vault Integration](#key-vault-integration)
12. [Database Migration](#database-migration)
13. [Monitoring and Logging](#monitoring-and-logging)
14. [Security Best Practices](#security-best-practices)
15. [Troubleshooting](#troubleshooting)

---

## Overview

The Azure integration includes:

- **Multi-stage CI/CD pipeline** with Azure Pipelines
- **Infrastructure as Code** using Bicep and Terraform
- **Container-based deployment** to Azure App Service (Linux Web App for Containers)
- **Optional AKS deployment** for Kubernetes orchestration
- **Azure Key Vault** for secrets management
- **Azure SQL Database** for data persistence
- **Application Insights** for monitoring and telemetry
- **Managed Identity** for secure access to Azure resources

## Prerequisites

### Required Tools

1. **Azure CLI** (version 2.40+)
   ```bash
   # Install on macOS
   brew install azure-cli
   
   # Install on Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Verify installation
   az --version
   ```

2. **Azure Account and Subscription**
   - Active Azure subscription
   - Sufficient permissions to create resources and service principals

3. **Azure DevOps Organization and Project**
   - Access to Azure DevOps
   - Project with Git repository

4. **Optional: Terraform** (if using Terraform instead of Bicep)
   ```bash
   brew install terraform  # macOS
   # Or download from https://www.terraform.io/downloads
   ```

### Required Permissions

- **Azure Subscription**: Contributor or Owner role
- **Azure AD**: Ability to create service principals and app registrations
- **Azure DevOps**: Project Administrator or Build Administrator

---

## Azure Resources Required

The infrastructure templates create the following Azure resources:

| Resource Type | Purpose | Naming Convention |
|--------------|---------|-------------------|
| Resource Group | Container for all resources | `rg-brettappscode-{env}` |
| Container Registry (ACR) | Store Docker images | `acrbrettappscode{unique}` |
| App Service Plan | Host the web application | `asp-brettappscode-{env}` |
| App Service | Run the containerized app | `app-brettappscode-{env}` |
| Key Vault | Store secrets and credentials | `kv-brettappscode{unique}` |
| SQL Server | Database server | `sql-brettappscode{unique}` |
| SQL Database | Application database | `brettappsdb` |
| Storage Account | File storage | `stbrettappscode{unique}` |
| Application Insights | Application monitoring | `appi-brettappscode-{env}` |
| Log Analytics | Centralized logging | `law-brettappscode-{env}` |

**Note**: Some resource names must be globally unique across Azure (ACR, Storage, Key Vault, SQL Server).

---

## Service Principal Setup

### Create Service Principal

Create a service principal for Azure DevOps to authenticate with Azure:

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "your-subscription-id"

# Create service principal
az ad sp create-for-rbac \
  --name "sp-brettappscode-devops" \
  --role Contributor \
  --scopes /subscriptions/{subscription-id}
```

**Save the output** - you'll need these values:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "sp-brettappscode-devops",
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### Grant Additional Permissions

Grant the service principal permissions to create resources:

```bash
# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp show --id {appId} --query id -o tsv)

# Grant User Access Administrator role (for assigning managed identity permissions)
az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope /subscriptions/{subscription-id}
```

---

## Azure DevOps Setup

### Create Service Connection

1. **Navigate to Project Settings** in Azure DevOps
2. Go to **Service connections** under Pipelines
3. Click **New service connection**
4. Select **Azure Resource Manager**
5. Choose **Service principal (manual)**
6. Fill in the details from the service principal creation:
   - **Subscription ID**: Your Azure subscription ID
   - **Subscription Name**: Your subscription name
   - **Service Principal ID**: The `appId` from above
   - **Service Principal Key**: The `password` from above
   - **Tenant ID**: The `tenant` from above
7. **Service connection name**: `AzureServiceConnection` (or your preferred name)
8. Check **Grant access permission to all pipelines**
9. Click **Verify and save**

### Create Pipeline

1. Go to **Pipelines** in Azure DevOps
2. Click **New pipeline**
3. Select your repository source (Azure Repos Git, GitHub, etc.)
4. Select **Existing Azure Pipelines YAML file**
5. Choose the branch and path: `azure-pipelines.yml`
6. Click **Continue**
7. Review and click **Save** (don't run yet - configure variables first)

---

## Pipeline Variables Configuration

### Required Pipeline Variables

Configure these variables in Azure DevOps Pipeline:

#### Navigate to: Pipelines → Your Pipeline → Edit → Variables

| Variable Name | Value | Secret | Description |
|--------------|-------|--------|-------------|
| `AZURE_SERVICE_CONNECTION` | `AzureServiceConnection` | No | Name of the Azure service connection |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID | No | Azure subscription ID |
| `RG_NAME` | `rg-brettappscode-prod` | No | Resource group name |
| `LOCATION` | `eastus` | No | Azure region |
| `ACR_NAME` | `acrbrettappscode001` | No | Container registry name (globally unique) |
| `ACR_LOGIN_SERVER` | `acrbrettappscode001.azurecr.io` | No | ACR login server URL |
| `APP_SERVICE_NAME` | `app-brettappscode-prod` | No | App Service name (globally unique) |
| `KEY_VAULT_NAME` | `kv-brettappscode01` | No | Key Vault name (globally unique) |
| `SQL_SERVER_NAME` | `sql-brettappscode01` | No | SQL Server name (globally unique) |
| `SQL_DB_NAME` | `brettappsdb` | No | SQL Database name |
| `SQL_ADMIN_LOGIN` | `sqladmin` | Yes | SQL admin username |
| `SQL_ADMIN_PASSWORD` | `YourSecurePass123!` | Yes | SQL admin password (strong password) |
| `STORAGE_ACCOUNT_NAME` | `stbrettappscode01` | No | Storage account name (lowercase, globally unique) |
| `APP_INSIGHTS_NAME` | `appi-brettappscode-prod` | No | Application Insights name |
| `DEPLOY_INFRASTRUCTURE` | `true` or `false` | No | Set to `true` for first deployment |

#### Optional Variables (for AKS deployment)

| Variable Name | Value | Secret | Description |
|--------------|-------|--------|-------------|
| `DEPLOY_TO_AKS` | `true` or `false` | No | Enable AKS deployment |
| `AKS_CLUSTER_NAME` | `aks-brettappscode-prod` | No | AKS cluster name |

### Variable Groups (Recommended)

Create a variable group for better organization:

1. Go to **Pipelines → Library**
2. Click **+ Variable group**
3. Name: `Azure-Production`
4. Add all variables above
5. Link to Azure Key Vault (optional but recommended):
   - Toggle **Link secrets from an Azure key vault**
   - Select your subscription and Key Vault
   - Authorize the connection
6. Save

Update your pipeline to use the variable group:

```yaml
variables:
  - group: Azure-Production
```

---

## Infrastructure Deployment

### Option 1: Using Bicep (Recommended)

The pipeline automatically deploys infrastructure using the Bicep template when `DEPLOY_INFRASTRUCTURE=true`.

**Manual deployment**:

```bash
# Login and set subscription
az login
az account set --subscription "your-subscription-id"

# Create resource group
az group create --name rg-brettappscode-prod --location eastus

# Deploy Bicep template
az deployment group create \
  --resource-group rg-brettappscode-prod \
  --template-file iac/bicep/main.bicep \
  --parameters \
    location=eastus \
    acrName=acrbrettappscode001 \
    appServiceName=app-brettappscode-prod \
    keyVaultName=kv-brettappscode01 \
    sqlServerName=sql-brettappscode01 \
    sqlDatabaseName=brettappsdb \
    storageAccountName=stbrettappscode01 \
    appInsightsName=appi-brettappscode-prod \
    sqlAdminLogin=sqladmin \
    sqlAdminPassword='YourSecurePass123!'
```

### Option 2: Using Terraform

See [iac/terraform/README.md](../iac/terraform/README.md) for detailed Terraform instructions.

**Quick start**:

```bash
cd iac/terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars with your values
# (See terraform/README.md for example)

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

---

## Pipeline Execution

### First Deployment (with Infrastructure)

1. **Set `DEPLOY_INFRASTRUCTURE` to `true`**
2. **Commit and push** changes to the `main` branch
3. **Pipeline stages**:
   - ✅ Build and Test
   - ✅ Docker Build and Push
   - ✅ Deploy Infrastructure
   - ✅ Deploy to App Service

### Subsequent Deployments (without Infrastructure)

1. **Set `DEPLOY_INFRASTRUCTURE` to `false`**
2. **Commit and push** changes
3. **Pipeline stages**:
   - ✅ Build and Test
   - ✅ Docker Build and Push
   - ✅ Deploy to App Service (infrastructure stage skipped)

### Manual Pipeline Run

1. Go to **Pipelines** in Azure DevOps
2. Select your pipeline
3. Click **Run pipeline**
4. Select branch and variables
5. Click **Run**

---

## Post-Deployment Configuration

### Configure Managed Identity Access to Key Vault

This is automatically done by the pipeline, but if needed manually:

```bash
# Get App Service managed identity principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name app-brettappscode-prod \
  --resource-group rg-brettappscode-prod \
  --query principalId -o tsv)

# Grant Key Vault access
az keyvault set-policy \
  --name kv-brettappscode01 \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

### Store Additional Secrets in Key Vault

```bash
# Store API keys
az keyvault secret set \
  --vault-name kv-brettappscode01 \
  --name "DEEPSEEK-API-KEY" \
  --value "your-api-key"

az keyvault secret set \
  --vault-name kv-brettappscode01 \
  --name "GEMINI-API-KEY" \
  --value "your-api-key"

# Store database connection string
az keyvault secret set \
  --vault-name kv-brettappscode01 \
  --name "DATABASE-CONNECTION-STRING" \
  --value "Server=sql-brettappscode01.database.windows.net;Database=brettappsdb;..."
```

### Configure App Service Settings to Use Key Vault

```bash
# Reference Key Vault secrets in App Service settings
az webapp config appsettings set \
  --name app-brettappscode-prod \
  --resource-group rg-brettappscode-prod \
  --settings \
    DEEPSEEK_API_KEY="@Microsoft.KeyVault(SecretUri=https://kv-brettappscode01.vault.azure.net/secrets/DEEPSEEK-API-KEY/)" \
    GEMINI_API_KEY="@Microsoft.KeyVault(SecretUri=https://kv-brettappscode01.vault.azure.net/secrets/GEMINI-API-KEY/)"
```

---

## Azure AD Authentication

### Register Application in Azure AD

1. **Navigate to Azure Portal** → Azure Active Directory → App registrations
2. Click **New registration**
3. **Name**: `brettappscode`
4. **Supported account types**: Select based on your needs
5. **Redirect URI**: 
   - Platform: Web
   - URI: `https://app-brettappscode-prod.azurewebsites.net/auth/callback`
6. Click **Register**

### Configure Authentication

1. Go to **Authentication** in your app registration
2. Add platform: **Web**
3. Add Redirect URIs:
   ```
   https://app-brettappscode-prod.azurewebsites.net/auth/callback
   https://app-brettappscode-prod.azurewebsites.net/auth/signin-oidc
   ```
4. **Implicit grant**: Check **ID tokens**
5. Save

### Store Azure AD Configuration in Key Vault

```bash
az keyvault secret set \
  --vault-name kv-brettappscode01 \
  --name "AZURE-AD-CLIENT-ID" \
  --value "your-application-client-id"

az keyvault secret set \
  --vault-name kv-brettappscode01 \
  --name "AZURE-AD-CLIENT-SECRET" \
  --value "your-client-secret"

az keyvault secret set \
  --vault-name kv-brettappscode01 \
  --name "AZURE-AD-TENANT-ID" \
  --value "your-tenant-id"
```

### Example: Implement Azure AD Sign-In in Node.js

Install MSAL library:

```bash
npm install @azure/msal-node
```

Example authentication middleware:

```javascript
const msal = require('@azure/msal-node');

const msalConfig = {
  auth: {
    clientId: process.env.AZURE_AD_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${process.env.AZURE_AD_TENANT_ID}`,
    clientSecret: process.env.AZURE_AD_CLIENT_SECRET,
  }
};

const pca = new msal.ConfidentialClientApplication(msalConfig);

// Middleware to check authentication
function ensureAuthenticated(req, res, next) {
  if (req.session.account) {
    return next();
  }
  res.redirect('/auth/signin');
}
```

**Resources**:
- [MSAL Node.js Documentation](https://github.com/AzureAD/microsoft-authentication-library-for-js/tree/dev/lib/msal-node)
- [Azure AD Authentication Samples](https://github.com/Azure-Samples/ms-identity-javascript-nodejs-tutorial)

---

## Key Vault Integration

### Using Managed Identity in Node.js

See [src/samples/keyvault-nodejs.md](../src/samples/keyvault-nodejs.md) for complete code samples.

**Quick example**:

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

const keyVaultName = process.env.KEY_VAULT_NAME;
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;

const credential = new DefaultAzureCredential();
const client = new SecretClient(keyVaultUrl, credential);

async function getSecret(secretName) {
  const secret = await client.getSecret(secretName);
  return secret.value;
}
```

---

## Database Migration

### Connect to Azure SQL Database

**Connection string format**:

```
Server=sql-brettappscode01.database.windows.net,1433;
Database=brettappsdb;
User ID=sqladmin;
Password={password};
Encrypt=true;
Connection Timeout=30;
```

### Add Database Migration to Pipeline

Add a migration task to your pipeline:

```yaml
- task: AzureCLI@2
  displayName: 'Run Database Migrations'
  inputs:
    azureSubscription: $(AZURE_SERVICE_CONNECTION)
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Example using a Node.js migration script
      npm run migrate
      
      # Or using SQL scripts
      sqlcmd -S $(SQL_SERVER_NAME).database.windows.net \
        -d $(SQL_DB_NAME) \
        -U $(SQL_ADMIN_LOGIN) \
        -P $(SQL_ADMIN_PASSWORD) \
        -i migrations/schema.sql
```

### Example: Using Sequelize ORM

```javascript
const { Sequelize } = require('sequelize');
const { getSecret } = require('./keyvault-helper');

async function initializeDatabase() {
  const connectionString = await getSecret('DATABASE-CONNECTION-STRING');
  
  const sequelize = new Sequelize(connectionString, {
    dialect: 'mssql',
    dialectOptions: {
      encrypt: true
    }
  });
  
  await sequelize.authenticate();
  console.log('Database connection established');
  
  return sequelize;
}
```

---

## Monitoring and Logging

### Application Insights

Application Insights is automatically configured by the infrastructure templates.

**View metrics**:
1. Navigate to Application Insights in Azure Portal
2. View **Live Metrics**, **Performance**, **Failures**
3. Use **Logs** (Kusto queries) for advanced analysis

### Enable Application Insights in Node.js

Install the SDK:

```bash
npm install applicationinsights
```

Add to your `server.js`:

```javascript
const appInsights = require('applicationinsights');

if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .setSendLiveMetrics(true)
    .start();
    
  console.log('Application Insights initialized');
}
```

### View App Service Logs

```bash
# Stream logs
az webapp log tail \
  --name app-brettappscode-prod \
  --resource-group rg-brettappscode-prod

# Download logs
az webapp log download \
  --name app-brettappscode-prod \
  --resource-group rg-brettappscode-prod \
  --log-file app-logs.zip
```

---

## Security Best Practices

### 1. Managed Identity

✅ **Use Managed Identity** instead of service principal credentials where possible
- Automatically rotated credentials
- No secrets to manage in code

### 2. Key Vault

✅ **Store all secrets in Key Vault**
- API keys
- Connection strings
- Certificates
- Passwords

❌ **Never hardcode secrets** in code or configuration files

### 3. Network Security

✅ **Configure IP restrictions** on App Service if needed:

```bash
az webapp config access-restriction add \
  --name app-brettappscode-prod \
  --resource-group rg-brettappscode-prod \
  --rule-name AllowOfficeIP \
  --action Allow \
  --ip-address 203.0.113.0/24 \
  --priority 100
```

✅ **Enable Private Endpoints** for SQL and Storage in production

### 4. HTTPS and TLS

✅ **HTTPS Only** is enabled by default
✅ **Minimum TLS version** 1.2 is enforced

### 5. RBAC and Least Privilege

✅ **Use Role-Based Access Control**:
- Service Principal: Contributor (scoped to resource group)
- App Service Managed Identity: Key Vault Secrets User
- Pipeline: Minimum permissions needed

### 6. Rotate Credentials

✅ **Regularly rotate**:
- SQL admin password
- Service principal secrets
- API keys

### 7. Enable Diagnostic Logging

```bash
az monitor diagnostic-settings create \
  --name DiagnosticSettings \
  --resource /subscriptions/{sub-id}/resourceGroups/rg-brettappscode-prod/providers/Microsoft.Web/sites/app-brettappscode-prod \
  --logs '[{"category": "AppServiceHTTPLogs", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]' \
  --workspace /subscriptions/{sub-id}/resourceGroups/rg-brettappscode-prod/providers/Microsoft.OperationalInsights/workspaces/law-brettappscode-prod
```

---

## Troubleshooting

### Pipeline Fails at Infrastructure Deployment

**Issue**: Resource name already exists

**Solution**: Ensure globally unique names for ACR, Storage, Key Vault, SQL Server

```bash
# Check if name is available
az storage account check-name --name stbrettappscode01
az keyvault check-name --name kv-brettappscode01
```

### Docker Image Push Fails

**Issue**: Authentication to ACR fails

**Solution**: Verify service connection and ACR admin enabled

```bash
# Enable ACR admin user
az acr update --name acrbrettappscode001 --admin-enabled true

# Get credentials
az acr credential show --name acrbrettappscode001
```

### App Service Deployment Succeeds but App Doesn't Work

**Issue**: Container not starting

**Solution**: Check logs

```bash
# View container logs
az webapp log tail --name app-brettappscode-prod --resource-group rg-brettappscode-prod

# Check container settings
az webapp config container show --name app-brettappscode-prod --resource-group rg-brettappscode-prod
```

### Key Vault Access Denied

**Issue**: App Service can't read secrets

**Solution**: Grant managed identity access

```bash
# Get principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name app-brettappscode-prod \
  --resource-group rg-brettappscode-prod \
  --query principalId -o tsv)

# Grant access
az keyvault set-policy \
  --name kv-brettappscode01 \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

### SQL Connection Fails

**Issue**: Can't connect to Azure SQL

**Solution**: Check firewall rules

```bash
# Add your IP to SQL firewall
az sql server firewall-rule create \
  --resource-group rg-brettappscode-prod \
  --server sql-brettappscode01 \
  --name AllowMyIP \
  --start-ip-address YOUR_IP \
  --end-ip-address YOUR_IP

# Verify Azure services access
az sql server firewall-rule show \
  --resource-group rg-brettappscode-prod \
  --server sql-brettappscode01 \
  --name AllowAzureServices
```

---

## Additional Resources

### Documentation

- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure Pipelines YAML Reference](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)

### Sample Code

- Key Vault Integration: [src/samples/keyvault-nodejs.md](../src/samples/keyvault-nodejs.md)
- Azure AD Authentication: [Microsoft Identity Samples](https://github.com/Azure-Samples/ms-identity-javascript-nodejs-tutorial)

### Support

- **Azure Support**: [Azure Portal](https://portal.azure.com) → Help + support
- **Azure DevOps Support**: [Azure DevOps Services](https://developercommunity.visualstudio.com/AzureDevOps)
- **Community**: [Stack Overflow - Azure](https://stackoverflow.com/questions/tagged/azure)

---

## Next Steps

1. ✅ Complete service principal setup
2. ✅ Configure pipeline variables
3. ✅ Run first deployment with infrastructure
4. ✅ Verify application is running
5. ✅ Configure Key Vault secrets
6. ✅ Set up Application Insights monitoring
7. ✅ Implement database migrations
8. ✅ Configure Azure AD authentication (if needed)
9. ✅ Set up alerts and monitoring
10. ✅ Document custom configuration

---

**Questions or Issues?**

Please open an issue in the repository or contact the DevOps team.
