# Azure Integration Guide

This guide provides step-by-step instructions for setting up Azure integration with this repository, including CI/CD pipelines, infrastructure deployment, and Azure service configuration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure DevOps Setup](#azure-devops-setup)
3. [Pipeline Variables and Secrets](#pipeline-variables-and-secrets)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Azure Services Configuration](#azure-services-configuration)
6. [Running the Pipeline](#running-the-pipeline)
7. [Security Best Practices](#security-best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before setting up Azure integration, ensure you have:

- **Azure Subscription**: An active Azure subscription with appropriate permissions
- **Azure DevOps Organization**: Access to Azure DevOps (dev.azure.com)
- **Azure CLI**: Installed locally for testing ([Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **Repository Access**: Admin access to this GitHub repository
- **Docker**: (Optional) For local container testing

---

## Azure DevOps Setup

### 1. Create Azure Service Connection

1. Navigate to your Azure DevOps project
2. Go to **Project Settings** → **Service connections**
3. Click **New service connection**
4. Select **Azure Resource Manager**
5. Choose authentication method:
   - **Service principal (automatic)** - Recommended for simplicity
   - **Service principal (manual)** - For advanced scenarios
6. Select your Azure subscription
7. Choose resource group scope or subscription scope
8. Name the service connection (e.g., `azure-service-connection`)
9. Check "Grant access permission to all pipelines" (or configure per-pipeline)
10. Click **Save**

**Important**: Note the service connection name - you'll use it in pipeline variables as `AZURE_SERVICE_CONNECTION`.

### 2. Create Pipeline in Azure DevOps

1. Go to **Pipelines** → **Create Pipeline**
2. Select **GitHub** as your code repository
3. Authorize Azure Pipelines to access your GitHub repository
4. Select this repository
5. Azure DevOps will detect the `azure-pipelines.yml` file
6. Review the pipeline configuration
7. Click **Run** to create and run the pipeline (first run may require approval)

---

## Pipeline Variables and Secrets

Configure the following variables in Azure DevOps:

### Required Pipeline Variables

Navigate to **Pipelines** → Select your pipeline → **Edit** → **Variables** → **New variable**

| Variable Name | Description | Example Value | Secret? |
|---------------|-------------|---------------|---------|
| `AZURE_SERVICE_CONNECTION` | Name of the Azure service connection | `azure-service-connection` | No |
| `RG_NAME` | Azure resource group name | `rg-brettappscode-prod` | No |
| `LOCATION` | Azure region | `eastus` | No |
| `ACR_NAME` | Azure Container Registry name (globally unique) | `acrbrettappscode` | No |
| `IMAGE_NAME` | Docker image name | `brettappscode` | No |
| `APP_SERVICE_NAME` | App Service name (globally unique) | `app-brettappscode` | No |
| `KEY_VAULT_NAME` | Key Vault name (globally unique, 3-24 chars) | `kv-brettappscode` | No |
| `SQL_SERVER_NAME` | SQL Server name (globally unique) | `sql-brettappscode` | No |
| `SQL_DB_NAME` | SQL Database name | `brettappscode-db` | No |
| `APP_INSIGHTS_NAME` | Application Insights name | `appi-brettappscode` | No |
| `SQL_ADMIN_PASSWORD` | SQL Server admin password (strong password) | `YourSecurePassword123!` | **Yes** |

**Note**: Mark `SQL_ADMIN_PASSWORD` as a secret by checking the "Keep this value secret" option.

### Naming Conventions

Follow Azure naming conventions:
- **Resource names**: lowercase, alphanumeric, hyphens (where allowed)
- **Globally unique names**: ACR, App Service, Key Vault, SQL Server, Storage Account
- **Max lengths**: Key Vault (24 chars), Storage Account (24 chars)

### Using Variable Groups (Optional)

For better organization, create a Variable Group:

1. Go to **Pipelines** → **Library** → **+ Variable group**
2. Name it (e.g., `azure-prod-config`)
3. Add all variables to the group
4. Reference in `azure-pipelines.yml`:
   ```yaml
   variables:
     - group: azure-prod-config
   ```

---

## Infrastructure Deployment

The pipeline deploys infrastructure using Bicep templates. The following resources are created:

### Azure Resources

1. **Azure Container Registry (ACR)**: Stores Docker images
2. **App Service Plan**: Linux-based hosting plan
3. **App Service (Web App for Containers)**: Hosts the containerized application
4. **Key Vault**: Stores secrets and connection strings
5. **Azure SQL Server & Database**: Relational database
6. **Storage Account**: Blob storage for file uploads
7. **Application Insights**: Application monitoring and telemetry

### Infrastructure as Code Options

**Option 1: Bicep (Default)**
- Template location: `iac/bicep/main.bicep`
- Deployed automatically by the pipeline
- Used in the `DeployInfrastructure` stage

**Option 2: Terraform (Alternative)**
- Template location: `iac/terraform/main.tf`
- To use Terraform instead of Bicep:
  1. Comment out the Bicep deployment stage in `azure-pipelines.yml`
  2. Add Terraform deployment tasks (example below)

Example Terraform deployment task:
```yaml
- task: TerraformInstaller@0
  inputs:
    terraformVersion: 'latest'

- task: TerraformTaskV4@4
  inputs:
    provider: 'azurerm'
    command: 'init'
    workingDirectory: '$(System.DefaultWorkingDirectory)/iac/terraform'

- task: TerraformTaskV4@4
  inputs:
    provider: 'azurerm'
    command: 'apply'
    workingDirectory: '$(System.DefaultWorkingDirectory)/iac/terraform'
    environmentServiceNameAzureRM: '$(AZURE_SERVICE_CONNECTION)'
```

---

## Azure Services Configuration

### 1. Azure Key Vault Integration

The application uses **Managed Identity** to access Key Vault secrets securely.

**Setup Steps:**
1. The pipeline automatically enables system-assigned managed identity for App Service
2. The pipeline grants the managed identity access to Key Vault (Get, List secrets)
3. The application uses `DefaultAzureCredential` to authenticate

**Using Key Vault in Node.js:**

Install the Azure SDK packages:
```bash
npm install @azure/identity @azure/keyvault-secrets
```

Sample code (see `src/samples/keyvault-nodejs.md` for full example):
```javascript
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

const keyVaultUrl = process.env.KEY_VAULT_URI;
const credential = new DefaultAzureCredential();
const client = new SecretClient(keyVaultUrl, credential);

// Retrieve a secret
const secret = await client.getSecret('my-secret-name');
console.log('Secret value:', secret.value);
```

**Storing Secrets:**
- Use Azure CLI or Azure Portal to add secrets to Key Vault
- Example (Azure CLI):
  ```bash
  az keyvault secret set --vault-name kv-brettappscode --name "api-key" --value "your-api-key-value"
  ```

### 2. Azure AD Authentication (Optional)

For user authentication and authorization using Azure Active Directory:

**Step 1: Register an Application in Azure AD**

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Enter application name (e.g., `brettappscode`)
4. Select supported account types (e.g., "Accounts in this organizational directory only")
5. Add Redirect URI (Web): `https://<APP_SERVICE_NAME>.azurewebsites.net/auth/redirect`
6. Click **Register**
7. Note the **Application (client) ID** and **Directory (tenant) ID**

**Step 2: Create a Client Secret**

1. In the app registration, go to **Certificates & secrets**
2. Click **New client secret**
3. Add description and expiration
4. Click **Add**
5. **Copy the secret value immediately** (it won't be shown again)

**Step 3: Configure API Permissions (if needed)**

1. Go to **API permissions**
2. Add permissions based on your needs (e.g., Microsoft Graph API for user profile)

**Step 4: Store Credentials in Key Vault**

```bash
az keyvault secret set --vault-name kv-brettappscode --name "azure-ad-client-id" --value "<CLIENT_ID>"
az keyvault secret set --vault-name kv-brettappscode --name "azure-ad-client-secret" --value "<CLIENT_SECRET>"
az keyvault secret set --vault-name kv-brettappscode --name "azure-ad-tenant-id" --value "<TENANT_ID>"
```

**Step 5: Use MSAL in Your Application**

Install MSAL for Node.js:
```bash
npm install @azure/msal-node
```

Documentation: [Microsoft Authentication Library (MSAL) for Node](https://learn.microsoft.com/en-us/azure/active-directory/develop/msal-overview)

### 3. Azure SQL Database

**Connection String:**
- Stored in App Service configuration as a connection string
- Also stored in Key Vault as `sql-admin-password` secret
- Access via `process.env.DefaultConnection` or retrieve from Key Vault

**Running Database Migrations:**
- Use your preferred ORM/migration tool (Sequelize, Knex, TypeORM, etc.)
- The pipeline has a `PostDeploy` stage placeholder for migrations
- Example for Knex:
  ```bash
  npm install knex
  npx knex migrate:latest
  ```

**Security Note:**
- Do NOT store SQL passwords in code or environment variables in source control
- Always retrieve from Key Vault in production

### 4. Azure Storage Account

**Blob Storage for File Uploads:**

Install Azure Storage SDK:
```bash
npm install @azure/storage-blob
```

Example code:
```javascript
const { BlobServiceClient } = require('@azure/storage-blob');
const { DefaultAzureCredential } = require('@azure/identity');

const accountName = process.env.STORAGE_ACCOUNT_NAME;
const blobServiceClient = new BlobServiceClient(
  `https://${accountName}.blob.core.windows.net`,
  new DefaultAzureCredential()
);

// Upload a file
const containerClient = blobServiceClient.getContainerClient('uploads');
const blockBlobClient = containerClient.getBlockBlobClient('filename.txt');
await blockBlobClient.uploadData(fileBuffer);
```

**Grant App Service Access to Storage:**
```bash
az role assignment create \
  --assignee <APP_SERVICE_PRINCIPAL_ID> \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT_NAME>
```

### 5. Application Insights

**Monitoring and Telemetry:**

Install Application Insights SDK:
```bash
npm install applicationinsights
```

Initialize in your app (e.g., in `server.js`):
```javascript
const appInsights = require('applicationinsights');

// Instrumentation key is automatically configured via environment variable
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
```

**View Telemetry:**
- Go to **Azure Portal** → **Application Insights** → Your instance
- View metrics, logs, failures, performance, etc.

---

## Running the Pipeline

### First Run

1. Ensure all pipeline variables are configured
2. Navigate to **Pipelines** in Azure DevOps
3. Click on your pipeline
4. Click **Run pipeline**
5. Select branch (default: `main`)
6. Click **Run**

**Pipeline Stages:**

1. **Build**: Builds and tests the Node.js application
2. **DeployInfrastructure**: Deploys Azure resources using Bicep
3. **DockerBuildPush**: Builds Docker image and pushes to ACR
4. **DeployAppService**: Deploys container to App Service
5. **PostDeploy**: Runs database migrations and smoke tests (optional)

**Approvals (Optional):**
- Configure environment approvals for production deployments
- Go to **Pipelines** → **Environments** → Create/select environment → **Approvals and checks**

### Subsequent Runs

- Pipeline triggers automatically on push to `main`, `develop`, or `azure/*` branches
- You can also trigger manually from Azure DevOps

---

## Security Best Practices

### 1. Use Managed Identities

- **Always** use managed identities for Azure service-to-service authentication
- Avoid storing credentials in code or configuration
- The pipeline configures system-assigned managed identity for App Service

### 2. Store Secrets in Key Vault

- **Never** commit secrets, API keys, or passwords to source control
- Store all secrets in Azure Key Vault
- Access secrets at runtime using managed identity

### 3. Principle of Least Privilege

- Grant only the minimum permissions required
- Use RBAC for fine-grained access control
- Regularly review and audit permissions

### 4. Rotate Credentials Regularly

- Rotate SQL passwords, client secrets, and API keys regularly
- Use Key Vault secret versions to manage rotation
- Update references after rotation

### 5. Enable HTTPS Only

- App Service is configured with `httpsOnly: true`
- Always use HTTPS endpoints
- Redirect HTTP to HTTPS

### 6. Network Security

- Consider using Virtual Networks (VNet) for private connectivity
- Use Private Endpoints for Azure services (Key Vault, SQL, Storage)
- Configure firewall rules and NSGs

### 7. Monitor and Alert

- Use Application Insights for monitoring
- Set up alerts for failures, performance issues, and security events
- Enable Azure Security Center recommendations

### 8. Backup and Disaster Recovery

- Enable automated backups for SQL Database
- Use geo-redundant storage for critical data
- Test disaster recovery procedures regularly

---

## Troubleshooting

### Common Issues

**Issue 1: Pipeline fails with "Service connection not found"**

**Solution:**
- Verify the `AZURE_SERVICE_CONNECTION` variable matches the service connection name exactly
- Ensure the service connection has access permissions for the pipeline
- Check service connection validity in **Project Settings** → **Service connections**

**Issue 2: ACR push fails with authentication error**

**Solution:**
- Verify ACR admin user is enabled in Bicep template (`adminUserEnabled: true`)
- Check ACR credentials in App Service configuration
- Re-run the infrastructure deployment stage

**Issue 3: App Service shows "Container not found" error**

**Solution:**
- Verify the Docker image was pushed successfully to ACR
- Check App Service logs: Go to **App Service** → **Deployment Center** → **Logs**
- Verify App Service configuration has correct ACR credentials
- Try restarting the App Service

**Issue 4: Key Vault access denied**

**Solution:**
- Ensure App Service managed identity is enabled
- Verify access policy is configured for the managed identity
- Check the principal ID matches: `az webapp identity show --name <APP_SERVICE_NAME> --resource-group <RG_NAME>`
- Re-run the infrastructure deployment to configure access policy

**Issue 5: SQL connection fails**

**Solution:**
- Verify firewall rules allow Azure services (0.0.0.0 - 0.0.0.0)
- Check connection string format and credentials
- Ensure SQL admin password is strong and meets Azure requirements
- Test connectivity using Azure Data Studio or SSMS

**Issue 6: Resource name already exists**

**Solution:**
- Azure resource names (ACR, App Service, Key Vault, SQL Server) must be globally unique
- Change the resource name in pipeline variables
- Use a unique suffix (e.g., `app-brettappscode-prod-001`)

### Viewing Logs

**Pipeline Logs:**
- Navigate to **Pipelines** → Select run → View stage/job logs

**App Service Logs:**
- Azure Portal → App Service → **Monitoring** → **Log stream**
- Or use Azure CLI: `az webapp log tail --name <APP_SERVICE_NAME> --resource-group <RG_NAME>`

**Application Insights:**
- Azure Portal → Application Insights → **Logs** → Query logs
- Use Kusto Query Language (KQL) for advanced queries

---

## Additional Resources

- [Azure DevOps Documentation](https://docs.microsoft.com/en-us/azure/devops/)
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Azure SQL Database Documentation](https://docs.microsoft.com/en-us/azure/azure-sql/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Application Insights Node.js](https://docs.microsoft.com/en-us/azure/azure-monitor/app/nodejs)

---

## Support

For issues or questions:
1. Check this documentation and troubleshooting section
2. Review Azure DevOps pipeline logs
3. Check Azure Portal for resource status and logs
4. Open an issue in this repository with detailed error messages and logs

---

**Last Updated**: 2025-10-31
