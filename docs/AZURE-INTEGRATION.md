# Azure Integration Guide

This document provides step-by-step instructions for setting up and deploying the brettappscode application to Azure using Azure DevOps Pipelines, Infrastructure as Code (Bicep/Terraform), and Azure services.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Azure Resources](#azure-resources)
4. [Azure DevOps Setup](#azure-devops-setup)
5. [Pipeline Configuration](#pipeline-configuration)
6. [Infrastructure Deployment](#infrastructure-deployment)
7. [Key Vault Integration](#key-vault-integration)
8. [Azure AD Authentication](#azure-ad-authentication)
9. [Database Setup](#database-setup)
10. [Application Insights](#application-insights)
11. [Security Best Practices](#security-best-practices)
12. [Troubleshooting](#troubleshooting)

## Overview

This repository includes Azure integration components:

- **Azure Pipelines CI/CD**: Multi-stage pipeline for build, test, Docker, deploy, and IaC
- **Infrastructure as Code**: Bicep and Terraform templates for Azure resources
- **Containerization**: Docker support with Azure Container Registry (ACR)
- **Deployment Targets**: Azure App Service (Web App for Containers) and optional AKS
- **Security**: Key Vault for secrets, Managed Identity, Azure AD authentication
- **Monitoring**: Application Insights integration
- **Database**: Azure SQL Database support

## Prerequisites

### Required Tools

- Azure subscription with appropriate permissions
- Azure DevOps organization and project
- Azure CLI (for local testing)
- Docker (for local container builds)
- Node.js 18.x (for local development)

### Required Permissions

- Contributor or Owner role on Azure subscription
- Project Administrator role in Azure DevOps project

## Azure Resources

The pipeline and IaC templates create the following Azure resources:

1. **Resource Group**: Container for all resources
2. **Azure Container Registry (ACR)**: Docker image registry
3. **App Service Plan**: Linux-based hosting plan
4. **App Service**: Web App for Containers
5. **Key Vault**: Secure secrets storage
6. **Azure SQL Server**: Database server
7. **Azure SQL Database**: Application database
8. **Storage Account**: File and blob storage
9. **Application Insights**: Monitoring and telemetry

## Azure DevOps Setup

### 1. Create Service Connection

1. Navigate to your Azure DevOps project
2. Go to **Project Settings** > **Service connections**
3. Click **New service connection** > **Azure Resource Manager**
4. Choose **Service principal (automatic)**
5. Select your Azure subscription
6. Select or create a resource group
7. Name the connection (e.g., `azure-service-connection`)
8. Click **Save**

### 2. Create Pipeline Variables

Navigate to **Pipelines** > **Library** > **Variable groups** or set variables in the pipeline directly:

#### Required Variables

| Variable Name | Description | Example Value |
|---------------|-------------|---------------|
| `AZURE_SERVICE_CONNECTION` | Name of the Azure service connection | `azure-service-connection` |
| `RG_NAME` | Resource group name | `brettappscode-rg` |
| `LOCATION` | Azure region | `eastus` |
| `ACR_NAME` | Azure Container Registry name (unique) | `brettappsacr` |
| `IMAGE_NAME` | Docker image name | `brettappscode` |
| `APP_SERVICE_NAME` | App Service name (unique) | `brettappscode-app` |
| `KEY_VAULT_NAME` | Key Vault name (unique) | `brettappscode-kv` |
| `SQL_SERVER_NAME` | SQL Server name (unique) | `brettappscode-sql` |
| `SQL_DB_NAME` | SQL Database name | `brettappscode-db` |
| `APP_INSIGHTS_NAME` | Application Insights name | `brettappscode-ai` |

#### Secure Variables (Mark as Secret)

| Variable Name | Description |
|---------------|-------------|
| `SQL_ADMIN_PASSWORD` | SQL Server admin password (strong password) |

**Note**: Azure resource names must be globally unique (ACR, App Service, Key Vault, SQL Server).

## Pipeline Configuration

### Running the Pipeline

1. Commit and push the azure-pipelines.yml and related files to your repository
2. In Azure DevOps, go to **Pipelines** > **New pipeline**
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Select `/azure-pipelines.yml`
6. Click **Run**

### Pipeline Stages

1. **Build**: Installs dependencies, builds, and tests the Node.js application
2. **Docker**: Builds Docker image and pushes to ACR
3. **IaC**: Deploys infrastructure using Bicep templates
4. **Deploy**: Deploys container image to App Service
5. **PostDeploy**: Runs database migrations and smoke tests

### Dockerfile

Create a `Dockerfile` in the repository root:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

### .dockerignore

Create a `.dockerignore` file:

```
node_modules
npm-debug.log
.env
.git
.gitignore
README.md
uploads
*.test.js
*.spec.js
```

## Infrastructure Deployment

### Using Bicep

The Bicep template is located at `iac/bicep/main.bicep`.

**Deploy manually (for testing):**

```bash
az login
az group create --name <RG_NAME> --location <LOCATION>

az deployment group create \
  --resource-group <RG_NAME> \
  --template-file iac/bicep/main.bicep \
  --parameters \
    acrName=<ACR_NAME> \
    appServiceName=<APP_SERVICE_NAME> \
    keyVaultName=<KEY_VAULT_NAME> \
    sqlServerName=<SQL_SERVER_NAME> \
    sqlDbName=<SQL_DB_NAME> \
    appInsightsName=<APP_INSIGHTS_NAME> \
    sqlAdminPassword='<STRONG_PASSWORD>'
```

### Using Terraform

The Terraform configuration is located at `iac/terraform/main.tf`.

**Deploy manually (for testing):**

1. Create `terraform.tfvars`:

```hcl
resource_group_name = "brettappscode-rg"
location            = "eastus"
acr_name            = "brettappsacr"
app_service_name    = "brettappscode-app"
key_vault_name      = "brettappscode-kv"
sql_server_name     = "brettappscode-sql"
sql_db_name         = "brettappscode-db"
app_insights_name   = "brettappscode-ai"
sql_admin_password  = "<STRONG_PASSWORD>"
```

2. Run Terraform commands:

```bash
cd iac/terraform
terraform init
terraform plan
terraform apply
```

## Key Vault Integration

### Setting Secrets in Key Vault

After deploying infrastructure, store secrets in Key Vault:

```bash
# SQL connection string
az keyvault secret set \
  --vault-name <KEY_VAULT_NAME> \
  --name "DatabaseConnectionString" \
  --value "Server=tcp:<SQL_SERVER_FQDN>,1433;Database=<SQL_DB_NAME>;User ID=sqladmin;Password=<SQL_ADMIN_PASSWORD>;Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;"

# API keys (example)
az keyvault secret set \
  --vault-name <KEY_VAULT_NAME> \
  --name "DeepSeekApiKey" \
  --value "<YOUR_API_KEY>"
```

### Using Secrets in App Service

Configure App Service to reference Key Vault secrets:

```bash
az webapp config appsettings set \
  --name <APP_SERVICE_NAME> \
  --resource-group <RG_NAME> \
  --settings \
    "DATABASE_CONNECTION_STRING=@Microsoft.KeyVault(SecretUri=https://<KEY_VAULT_NAME>.vault.azure.net/secrets/DatabaseConnectionString/)" \
    "DEEPSEEK_API_KEY=@Microsoft.KeyVault(SecretUri=https://<KEY_VAULT_NAME>.vault.azure.net/secrets/DeepSeekApiKey/)"
```

### Accessing Secrets in Node.js

See `src/samples/keyvault-nodejs.md` for code examples.

Install the Azure SDK:

```bash
npm install @azure/keyvault-secrets @azure/identity
```

Use `DefaultAzureCredential` to authenticate (works with Managed Identity in Azure):

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

## Azure AD Authentication

To enable Azure AD authentication for your application:

### 1. Register Application in Azure AD

1. Go to **Azure Portal** > **Azure Active Directory** > **App registrations**
2. Click **New registration**
3. Enter application name (e.g., `brettappscode`)
4. Select **Accounts in this organizational directory only**
5. Add redirect URI:
   - Web: `https://<APP_SERVICE_NAME>.azurewebsites.net/auth/callback`
   - For local dev: `http://localhost:3000/auth/callback`
6. Click **Register**

### 2. Configure Authentication

1. Note the **Application (client) ID** and **Directory (tenant) ID**
2. Go to **Certificates & secrets** > **New client secret**
3. Create a secret and note the value
4. Store in Key Vault:

```bash
az keyvault secret set \
  --vault-name <KEY_VAULT_NAME> \
  --name "AzureAdClientId" \
  --value "<CLIENT_ID>"

az keyvault secret set \
  --vault-name <KEY_VAULT_NAME> \
  --name "AzureAdClientSecret" \
  --value "<CLIENT_SECRET>"
```

### 3. Implement MSAL in Application

Use Microsoft Authentication Library (MSAL) for Node.js:

```bash
npm install @azure/msal-node
```

**Resources:**
- [MSAL Node.js documentation](https://learn.microsoft.com/en-us/azure/active-directory/develop/msal-node-overview)
- [Azure AD authentication samples](https://github.com/AzureAD/microsoft-authentication-library-for-js)

## Database Setup

### Connection String Handling

Store the SQL connection string in Key Vault (as shown above) and reference it in App Service app settings.

In your Node.js application:

```javascript
const connectionString = process.env.DATABASE_CONNECTION_STRING;
```

### Running Migrations

The pipeline includes a PostDeploy stage placeholder for migrations.

**For Knex.js:**

```bash
npx knex migrate:latest --env production
```

**For Sequelize:**

```bash
npx sequelize-cli db:migrate --env production
```

**For TypeORM:**

```bash
npm run typeorm migration:run
```

Update `azure-pipelines.yml` PostDeploy stage with your migration commands.

## Application Insights

### Instrumentation

Application Insights is automatically configured in App Service via app settings:
- `APPINSIGHTS_INSTRUMENTATIONKEY`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`

### Adding SDK to Node.js

Install Application Insights SDK:

```bash
npm install applicationinsights
```

Add to your `server.js`:

```javascript
const appInsights = require("applicationinsights");
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
  .setAutoCollectRequests(true)
  .setAutoCollectPerformance(true)
  .setAutoCollectExceptions(true)
  .setAutoCollectDependencies(true)
  .setAutoCollectConsole(true)
  .start();
```

### Viewing Telemetry

1. Go to **Azure Portal** > **Application Insights** > `<APP_INSIGHTS_NAME>`
2. View **Live Metrics**, **Performance**, **Failures**, **Logs**

## Security Best Practices

### 1. Managed Identity

- App Service uses **System-Assigned Managed Identity** to access Key Vault
- No credentials needed in code or configuration
- Configured automatically by Bicep/Terraform templates

### 2. Least Privilege

- Service principal has only necessary permissions
- App Service identity has only Key Vault Secrets User role
- Review and adjust Azure RBAC roles as needed

### 3. Secrets Management

- **Never commit secrets** to source control
- Store all secrets in Azure Key Vault
- Use pipeline secret variables for deployment secrets
- Rotate credentials regularly

### 4. Network Security

- App Service and SQL Server accept HTTPS/TLS only
- Consider using **Private Endpoints** for production (requires VNet)
- Configure **SQL firewall rules** to restrict access

### 5. Monitoring and Alerts

- Enable Application Insights alerts for failures and performance issues
- Set up Azure Monitor alerts for resource health
- Review logs regularly

### 6. Secure Deployment

- Use separate environments (dev, staging, production)
- Require pull request reviews
- Enable branch protection rules
- Use separate service connections per environment

## Troubleshooting

### Pipeline Failures

**Issue**: Service connection not found
- **Solution**: Verify service connection name matches `AZURE_SERVICE_CONNECTION` variable

**Issue**: ACR login failed
- **Solution**: Check ACR name is unique and service principal has permissions

**Issue**: Bicep/Terraform deployment fails
- **Solution**: Check resource names are globally unique and within Azure naming constraints

### App Service Issues

**Issue**: Container fails to start
- **Solution**: Check container logs in App Service > Deployment Center > Logs

**Issue**: Key Vault access denied
- **Solution**: Verify managed identity role assignment and Key Vault RBAC settings

**Issue**: SQL connection fails
- **Solution**: Check firewall rules allow Azure services and connection string is correct

### Database Migrations

**Issue**: Migration fails
- **Solution**: Verify connection string in Key Vault and migration tool is installed

### General Debugging

- Check Azure DevOps pipeline logs for detailed error messages
- Use `az webapp log tail` to view App Service logs in real-time
- Check Application Insights for runtime errors and exceptions

## Next Steps

1. Customize the pipeline for your specific needs (e.g., add testing stages, security scans)
2. Set up multiple environments (dev, staging, production)
3. Configure custom domains and SSL certificates
4. Implement advanced monitoring and alerting
5. Set up Azure Front Door or Application Gateway for load balancing
6. Consider using Azure DevOps Environments with approvals for production deployments

## Additional Resources

- [Azure DevOps Documentation](https://learn.microsoft.com/en-us/azure/devops/)
- [Azure App Service Documentation](https://learn.microsoft.com/en-us/azure/app-service/)
- [Azure Container Registry Documentation](https://learn.microsoft.com/en-us/azure/container-registry/)
- [Azure Key Vault Documentation](https://learn.microsoft.com/en-us/azure/key-vault/)
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Application Insights Documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
