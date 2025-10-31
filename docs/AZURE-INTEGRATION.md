# Azure Integration Guide

This document provides step-by-step instructions for setting up and deploying the BrettAppsCode application to Microsoft Azure using Azure DevOps Pipelines, Infrastructure as Code (IaC), and Azure platform services.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Azure Resources](#azure-resources)
- [Setup Instructions](#setup-instructions)
  - [1. Azure DevOps Setup](#1-azure-devops-setup)
  - [2. Configure Pipeline Variables](#2-configure-pipeline-variables)
  - [3. Deploy Infrastructure](#3-deploy-infrastructure)
  - [4. Run the Pipeline](#4-run-the-pipeline)
- [Azure Services Integration](#azure-services-integration)
  - [Azure Container Registry](#azure-container-registry)
  - [App Service (Web App for Containers)](#app-service-web-app-for-containers)
  - [Azure Key Vault](#azure-key-vault)
  - [Azure SQL Database](#azure-sql-database)
  - [Application Insights](#application-insights)
  - [Azure Storage Account](#azure-storage-account)
- [Azure AD Authentication](#azure-ad-authentication)
- [Security Best Practices](#security-best-practices)
- [Monitoring and Logging](#monitoring-and-logging)
- [Troubleshooting](#troubleshooting)

## Overview

This integration provides a complete CI/CD pipeline and infrastructure setup for deploying the BrettAppsCode application to Azure. The solution includes:

- **Multi-stage Azure Pipelines**: Build, test, containerize, and deploy
- **Infrastructure as Code**: Bicep and Terraform templates
- **Container Deployment**: Docker image stored in ACR, deployed to App Service
- **Security**: Key Vault for secrets, Managed Identity for authentication
- **Monitoring**: Application Insights for performance and diagnostics
- **Database**: Azure SQL Database for data persistence
- **Storage**: Azure Storage Account for file storage

## Prerequisites

Before you begin, ensure you have:

1. **Azure Subscription**: An active Azure subscription with Contributor or Owner access
2. **Azure DevOps Organization**: An Azure DevOps account and organization
3. **Azure CLI**: Installed locally for manual operations (optional)
4. **Git**: For version control
5. **Permissions**: Ability to create service principals and resource groups

## Azure Resources

The following Azure resources will be created:

| Resource Type | Purpose | Cost Tier |
|--------------|---------|-----------|
| Resource Group | Container for all resources | Free |
| Azure Container Registry (ACR) | Store Docker images | Basic ($5/month) |
| App Service Plan | Hosting for App Service | B1 (~$13/month) |
| App Service | Web application hosting | Included in plan |
| Key Vault | Secure secrets storage | Standard ($0.03 per 10k ops) |
| Azure SQL Server | Database server | - |
| Azure SQL Database | Application database | Basic ($5/month) |
| Storage Account | File and blob storage | Standard LRS (~$2/month) |
| Application Insights | Monitoring and diagnostics | Pay-as-you-go |
| Log Analytics Workspace | Logs aggregation | Pay-as-you-go |

**Estimated Total**: ~$25-30/month for basic tier

## Setup Instructions

### 1. Azure DevOps Setup

#### A. Create an Azure DevOps Project

1. Navigate to [Azure DevOps](https://dev.azure.com)
2. Create a new project or use an existing one
3. Go to **Repos** and import or push your repository

#### B. Create Azure Service Connection

1. In Azure DevOps, go to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager** → **Next**
3. Select **Service principal (automatic)**
4. Choose your Azure subscription
5. Select or create a resource group (optional at this stage)
6. Name the service connection (e.g., `azure-production`)
7. Check **Grant access permission to all pipelines**
8. Click **Save**

**Important**: Note the service connection name - you'll need it for pipeline variables.

### 2. Configure Pipeline Variables

You need to configure the following variables in Azure Pipelines:

#### A. Navigate to Pipeline Variables

1. Go to **Pipelines** → **Library** → **Variable groups**
2. Create a new variable group named `azure-config`
3. Add the following variables:

#### B. Required Pipeline Variables

| Variable Name | Description | Example Value | Secret? |
|--------------|-------------|---------------|---------|
| `AZURE_SERVICE_CONNECTION` | Name of Azure service connection | `azure-production` | No |
| `RG_NAME` | Resource group name | `brettappscode-rg` | No |
| `LOCATION` | Azure region | `eastus` | No |
| `ACR_NAME` | Container Registry name (alphanumeric only) | `brettappsacr` | No |
| `IMAGE_NAME` | Docker image name | `brettappscode` | No |
| `APP_SERVICE_NAME` | App Service name | `brettappscode-app` | No |
| `KEY_VAULT_NAME` | Key Vault name (3-24 chars) | `brettappskv` | No |
| `SQL_SERVER_NAME` | SQL Server name | `brettappscode-sql` | No |
| `SQL_DB_NAME` | SQL Database name | `brettappsdb` | No |
| `SQL_ADMIN_PASSWORD` | SQL admin password (min 8 chars) | `YourSecurePassword123!` | **Yes** |
| `APP_INSIGHTS_NAME` | Application Insights name | `brettappscode-insights` | No |

#### C. Create the Variables

For each variable:
1. Click **+ Add** in the variable group
2. Enter the variable name and value
3. For `SQL_ADMIN_PASSWORD`, click the **lock icon** to mark it as secret
4. Click **Save**

#### D. Link Variable Group to Pipeline

1. Go to **Pipelines** → Select your pipeline
2. Click **Edit**
3. Click the **Variables** button
4. Click **Variable groups**
5. Link the `azure-config` variable group
6. Save

### 3. Deploy Infrastructure

You have two options for deploying infrastructure: Bicep (recommended) or Terraform.

#### Option A: Using Bicep (via Pipeline)

The pipeline will automatically deploy Bicep templates in the `DeployInfrastructure` stage. No manual action required.

#### Option B: Using Terraform (Manual)

If you prefer Terraform, deploy manually before running the pipeline:

```bash
# Navigate to Terraform directory
cd iac/terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# (Use a text editor to fill in resource names)

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan
```

### 4. Run the Pipeline

#### A. Create Pipeline from YAML

1. Go to **Pipelines** → **New pipeline**
2. Select **Azure Repos Git** (or your repo source)
3. Select your repository
4. Select **Existing Azure Pipelines YAML file**
5. Choose `/azure-pipelines.yml`
6. Click **Continue**
7. Review the pipeline YAML
8. Click **Run**

#### B. Monitor Pipeline Execution

The pipeline has multiple stages:

1. **Build**: Installs dependencies, runs tests, creates artifacts
2. **DockerBuild**: Builds Docker image and pushes to ACR
3. **DeployInfrastructure**: Deploys Azure resources using Bicep
4. **DeployAppService**: Deploys container to App Service
5. **PostDeploy**: Runs database migrations and smoke tests

Each stage must complete successfully before the next begins.

## Azure Services Integration

### Azure Container Registry

ACR stores your Docker images securely.

**Access the Registry:**
```bash
az acr login --name <ACR_NAME>
```

**Pull an Image:**
```bash
docker pull <ACR_NAME>.azurecr.io/brettappscode:latest
```

### App Service (Web App for Containers)

Your application runs in a containerized App Service.

**Access the Application:**
- URL: `https://<APP_SERVICE_NAME>.azurewebsites.net`

**View Logs:**
```bash
az webapp log tail --name <APP_SERVICE_NAME> --resource-group <RG_NAME>
```

**Restart App Service:**
```bash
az webapp restart --name <APP_SERVICE_NAME> --resource-group <RG_NAME>
```

### Azure Key Vault

Key Vault securely stores secrets, keys, and certificates.

#### Accessing Secrets from Node.js

The application uses Managed Identity to access Key Vault. See `src/samples/keyvault-nodejs.md` for code examples.

**Install Azure SDK:**
```bash
npm install @azure/keyvault-secrets @azure/identity
```

**Basic Usage:**
```javascript
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

const credential = new DefaultAzureCredential();
const vaultUrl = process.env.KEY_VAULT_URI;
const client = new SecretClient(vaultUrl, credential);

// Retrieve a secret
const secret = await client.getSecret('SqlConnectionString');
console.log(secret.value);
```

**Add Secrets via CLI:**
```bash
az keyvault secret set \
  --vault-name <KEY_VAULT_NAME> \
  --name "ApiKey" \
  --value "your-secret-value"
```

### Azure SQL Database

Azure SQL Database provides a managed relational database.

**Connection String:**
Stored in Key Vault as `SqlConnectionString`:
```
Server=tcp:<SQL_SERVER_NAME>.database.windows.net,1433;Database=<SQL_DB_NAME>;User ID=sqladmin;Password=<PASSWORD>;Encrypt=true;Connection Timeout=30;
```

**Connect from Node.js:**
```bash
npm install tedious
```

```javascript
const { Connection, Request } = require('tedious');

const config = {
  server: process.env.SQL_SERVER_NAME + '.database.windows.net',
  authentication: {
    type: 'default',
    options: {
      userName: 'sqladmin',
      password: process.env.SQL_ADMIN_PASSWORD
    }
  },
  options: {
    database: process.env.SQL_DB_NAME,
    encrypt: true
  }
};

const connection = new Connection(config);
connection.connect();
```

**Run Migrations:**
Add migration commands in the `PostDeploy` stage of `azure-pipelines.yml`:
```yaml
- script: |
    npx sequelize-cli db:migrate
  env:
    DATABASE_URL: $(SQL_CONNECTION_STRING)
```

### Application Insights

Application Insights provides monitoring, diagnostics, and analytics.

**Instrumentation Key:**
Automatically configured in App Service app settings as `APPINSIGHTS_INSTRUMENTATIONKEY`.

**Install Application Insights SDK:**
```bash
npm install applicationinsights
```

**Instrument Your Application:**

Add to the top of `server.js`:
```javascript
const appInsights = require('applicationinsights');

if (process.env.APPINSIGHTS_INSTRUMENTATIONKEY) {
  appInsights.setup(process.env.APPINSIGHTS_INSTRUMENTATIONKEY)
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .setSendLiveMetrics(false)
    .setDistributedTracingMode(appInsights.DistributedTracingModes.AI_AND_W3C)
    .start();
}
```

**View Metrics:**
1. Go to Azure Portal → Application Insights
2. View **Live Metrics**, **Failures**, **Performance**, etc.

### Azure Storage Account

Storage Account provides blob, file, queue, and table storage.

**Access from Node.js:**
```bash
npm install @azure/storage-blob
```

```javascript
const { BlobServiceClient } = require('@azure/storage-blob');

const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);

// Upload a file
const containerClient = blobServiceClient.getContainerClient('uploads');
await containerClient.createIfNotExists();

const blockBlobClient = containerClient.getBlockBlobClient('myfile.txt');
await blockBlobClient.upload(data, data.length);
```

## Azure AD Authentication

To add Azure AD authentication to your application:

### 1. Register Application in Azure AD

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Name: `BrettAppsCode`
4. Supported account types: **Accounts in this organizational directory only**
5. Redirect URI: 
   - Platform: **Web**
   - URI: `https://<APP_SERVICE_NAME>.azurewebsites.net/auth/callback`
6. Click **Register**

### 2. Configure Authentication

1. In the app registration, go to **Authentication**
2. Add additional redirect URIs if needed:
   - `https://<APP_SERVICE_NAME>.azurewebsites.net/.auth/login/aad/callback`
3. Enable **ID tokens** under **Implicit grant and hybrid flows**
4. Save

### 3. Get Application (Client) ID and Tenant ID

1. Go to **Overview** in your app registration
2. Copy **Application (client) ID**
3. Copy **Directory (tenant) ID**

### 4. Create Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Description: `App Service Secret`
4. Expires: 24 months (or as required)
5. Click **Add**
6. **Copy the secret value immediately** (it won't be shown again)

### 5. Store Credentials in Key Vault

```bash
az keyvault secret set --vault-name <KEY_VAULT_NAME> --name "AzureAdClientId" --value "<CLIENT_ID>"
az keyvault secret set --vault-name <KEY_VAULT_NAME> --name "AzureAdClientSecret" --value "<CLIENT_SECRET>"
az keyvault secret set --vault-name <KEY_VAULT_NAME> --name "AzureAdTenantId" --value "<TENANT_ID>"
```

### 6. Implement MSAL in Node.js

**Install MSAL:**
```bash
npm install @azure/msal-node
```

**Example Configuration:**
```javascript
const msal = require('@azure/msal-node');

const config = {
  auth: {
    clientId: process.env.AZURE_AD_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${process.env.AZURE_AD_TENANT_ID}`,
    clientSecret: process.env.AZURE_AD_CLIENT_SECRET
  }
};

const cca = new msal.ConfidentialClientApplication(config);
```

**Resources:**
- [MSAL Node Documentation](https://github.com/AzureAD/microsoft-authentication-library-for-js/tree/dev/lib/msal-node)
- [Azure AD with Express.js](https://docs.microsoft.com/en-us/azure/active-directory/develop/tutorial-v2-nodejs-webapp-msal)

## Security Best Practices

### 1. Use Managed Identity

- **App Service Managed Identity** is automatically enabled in the Bicep/Terraform templates
- Use Managed Identity to access Key Vault, Storage, SQL Database instead of connection strings
- No need to manage credentials manually

### 2. Secure Secrets

- **Never commit secrets** to source control
- Store all secrets in **Azure Key Vault**
- Use pipeline secret variables for deployment secrets
- Rotate secrets regularly

### 3. Least Privilege Access

- Grant only necessary permissions to Managed Identities
- Use Azure RBAC for fine-grained access control
- Review access policies regularly

### 4. Network Security

- Enable **HTTPS only** on App Service (already configured)
- Use **Private Endpoints** for Key Vault and SQL in production
- Configure **Virtual Network integration** for App Service
- Use **Azure Front Door** or **Application Gateway** for WAF

### 5. Enable Advanced Threat Protection

- Enable **Microsoft Defender for SQL**
- Enable **Microsoft Defender for Key Vault**
- Enable **Microsoft Defender for Containers** (ACR)
- Enable **Microsoft Defender for App Service**

### 6. Implement Logging and Monitoring

- Enable **diagnostic logs** on all resources
- Send logs to **Log Analytics Workspace**
- Set up **alerts** for security events
- Monitor with **Application Insights**

### 7. Database Security

- Use **strong passwords** (min 12 characters, mixed case, numbers, symbols)
- Enable **Transparent Data Encryption** (TDE) - enabled by default
- Enable **Advanced Data Security** for threat detection
- Use **Azure AD authentication** for SQL instead of SQL auth in production
- Restrict firewall rules to only necessary IPs

### 8. Regular Updates

- Keep **Node.js runtime** updated
- Update **npm packages** regularly (`npm audit`, `npm update`)
- Monitor **security advisories** for dependencies
- Update **base Docker images** regularly

## Monitoring and Logging

### Application Insights

**Key Metrics to Monitor:**
- Request rate and response time
- Failed requests
- Dependency calls (external APIs, database)
- Exceptions and errors
- Custom events

**Set Up Alerts:**
1. Go to Application Insights → **Alerts**
2. Create alert rules for:
   - Failed requests > threshold
   - Response time > threshold
   - Exceptions > threshold

### Log Analytics

**Query Logs:**
1. Go to Log Analytics Workspace → **Logs**
2. Use KQL (Kusto Query Language) to query logs:

```kql
// Recent errors
AppServiceConsoleLogs
| where TimeGenerated > ago(1h)
| where ResultDescription contains "error"
| order by TimeGenerated desc

// App Insights requests
requests
| where timestamp > ago(1h)
| summarize count() by resultCode
```

### App Service Logs

**Enable Logging:**
```bash
az webapp log config \
  --name <APP_SERVICE_NAME> \
  --resource-group <RG_NAME> \
  --application-logging filesystem \
  --detailed-error-messages true \
  --failed-request-tracing true \
  --web-server-logging filesystem
```

**Stream Logs:**
```bash
az webapp log tail --name <APP_SERVICE_NAME> --resource-group <RG_NAME>
```

## Troubleshooting

### Pipeline Failures

**Build Stage Fails:**
- Check Node.js version compatibility
- Ensure `package.json` has correct dependencies
- Review build logs for missing packages

**Docker Build Fails:**
- Verify Dockerfile syntax
- Check base image availability
- Ensure all COPY paths are correct

**Deployment Fails:**
- Verify service connection has correct permissions
- Check resource naming (must be unique globally for some resources)
- Review ARM/Bicep template for errors

### Application Issues

**App Service Not Starting:**
- Check App Service logs: `az webapp log tail ...`
- Verify Docker image was pushed to ACR
- Ensure PORT environment variable is set to 3000
- Check container health status

**Cannot Connect to SQL Database:**
- Verify firewall rules allow App Service
- Check connection string in Key Vault
- Ensure Managed Identity has access to Key Vault
- Test connection from App Service console

**Key Vault Access Denied:**
- Verify App Service Managed Identity is enabled
- Check Key Vault access policies include App Service principal
- Ensure `KEY_VAULT_URI` is set correctly

**Application Insights Not Showing Data:**
- Verify instrumentation key is set
- Check Application Insights SDK is installed and configured
- Wait 5-10 minutes for data to appear
- Review telemetry in Live Metrics for real-time debugging

### Common Error Messages

| Error | Solution |
|-------|----------|
| `ACR name already exists` | Choose a different, globally unique ACR name |
| `Key Vault name already in use` | Choose a different, globally unique Key Vault name |
| `Service connection not found` | Verify `AZURE_SERVICE_CONNECTION` variable is set correctly |
| `SQL password does not meet complexity requirements` | Use at least 8 characters with uppercase, lowercase, numbers, and symbols |
| `Container failed to start` | Check App Service logs for application errors |

### Get Support

- **Azure Support**: Open a support ticket in Azure Portal
- **Azure DevOps Support**: Visit [Azure DevOps Support](https://developercommunity.visualstudio.com/AzureDevOps)
- **Community**: [Stack Overflow](https://stackoverflow.com/questions/tagged/azure) with tag `azure`
- **Documentation**: [Azure Documentation](https://docs.microsoft.com/azure)

## Next Steps

1. **Set up Continuous Monitoring**: Configure alerts and dashboards
2. **Implement Blue-Green Deployment**: Use deployment slots for zero-downtime deployments
3. **Add Integration Tests**: Expand test coverage in the pipeline
4. **Set up Disaster Recovery**: Configure geo-redundancy and backup
5. **Optimize Costs**: Use Azure Cost Management to monitor and optimize spending
6. **Implement CDN**: Use Azure CDN for static assets
7. **Add Custom Domain**: Configure custom domain and SSL certificate

## Additional Resources

- [Azure DevOps Documentation](https://docs.microsoft.com/azure/devops/)
- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/azure/container-registry/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure SQL Database Documentation](https://docs.microsoft.com/azure/sql-database/)
- [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

**Note**: This guide is tailored for the BrettAppsCode application. Adjust resource names, configurations, and settings based on your specific requirements.
