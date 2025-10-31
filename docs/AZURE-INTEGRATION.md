# Azure DevOps Integration Documentation

This document describes the Azure DevOps CI/CD pipeline setup and Azure infrastructure integration for the brettappscode application.

## Overview

The Azure integration includes:
- **Multi-stage CI/CD pipeline** using Azure Pipelines
- **Infrastructure as Code (IaC)** using Bicep and Terraform
- **Container deployment** using Azure Container Registry (ACR) and App Service for Containers
- **Azure services integration**: Key Vault, SQL Database, Application Insights, Storage Account
- **Security best practices** with Managed Identity and least privilege access

## Architecture

### Pipeline Stages
1. **Build** - Node.js 18 build and test
2. **Docker Build** - Build and push Docker image to ACR
3. **Infrastructure Deploy** - Deploy Azure resources using Bicep
4. **Deploy to App Service** - Deploy containerized application
5. **Post-Deploy** - Run migrations and smoke tests

### Azure Resources
- **Azure Container Registry (ACR)** - Private Docker registry
- **App Service Plan** - Linux hosting plan
- **Web App for Containers** - Containerized Node.js app
- **Key Vault** - Secure secrets management
- **SQL Server & Database** - Relational database
- **Storage Account** - Blob storage for file uploads
- **Application Insights** - Application monitoring and telemetry
- **Log Analytics Workspace** - Centralized logging

## Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **Azure DevOps Organization** and Project
3. **Service Principal** or Service Connection with required permissions:
   - Contributor role on subscription or resource group
   - Permission to create resource groups
   - Permission to assign managed identities

## Setup Instructions

### 1. Create Azure Service Connection

In Azure DevOps:

1. Navigate to **Project Settings** > **Service connections**
2. Click **New service connection**
3. Select **Azure Resource Manager**
4. Choose **Service principal (automatic)** or **Service principal (manual)**
5. Configure the connection:
   - **Connection name**: `azure-service-connection` (or your preferred name)
   - **Subscription**: Select your Azure subscription
   - **Resource group**: Leave empty to allow access to all resource groups
6. Click **Save**

### 2. Configure Pipeline Variables

In Azure DevOps, configure the following pipeline variables (Pipeline > Edit > Variables):

#### Required Variables

| Variable Name | Description | Example Value | Secret? |
|--------------|-------------|---------------|---------|
| `AZURE_SERVICE_CONNECTION` | Name of the Azure service connection | `azure-service-connection` | No |
| `RG_NAME` | Resource group name | `rg-brettappscode-prod` | No |
| `LOCATION` | Azure region | `eastus` | No |
| `ACR_NAME` | Container registry name (must be globally unique) | `brettappsacr` | No |
| `IMAGE_NAME` | Docker image name | `brettappscode` | No |
| `APP_SERVICE_NAME` | App Service name (must be globally unique) | `brettappscode-webapp` | No |
| `KEY_VAULT_NAME` | Key Vault name (must be globally unique) | `brettappskv` | No |
| `SQL_SERVER_NAME` | SQL Server name (must be globally unique) | `brettappssql` | No |
| `SQL_DB_NAME` | SQL Database name | `brettappscode-db` | No |
| `APP_INSIGHTS_NAME` | Application Insights name | `brettapps-ai` | No |
| `SQL_ADMIN_PASSWORD` | SQL Server admin password | `YourStr0ngP@ssw0rd!` | **Yes** |

#### Variable Naming Guidelines
- **ACR name**: 5-50 alphanumeric characters, globally unique
- **App Service name**: 2-60 characters, globally unique
- **Key Vault name**: 3-24 alphanumeric and hyphens, globally unique
- **SQL Server name**: 1-63 lowercase letters, numbers, and hyphens, globally unique

### 3. Create the Pipeline

1. In Azure DevOps, navigate to **Pipelines** > **New Pipeline**
2. Select your repository source (GitHub, Azure Repos, etc.)
3. Select **Existing Azure Pipelines YAML file**
4. Choose `/azure-pipelines.yml`
5. Review and click **Run**

### 4. Grant Additional Permissions (if needed)

If using Managed Identity:
```bash
# Get the App Service managed identity principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name <APP_SERVICE_NAME> \
  --resource-group <RG_NAME> \
  --query principalId -o tsv)

# Grant SQL Database access
az sql server ad-admin create \
  --resource-group <RG_NAME> \
  --server-name <SQL_SERVER_NAME> \
  --display-name <APP_SERVICE_NAME> \
  --object-id $PRINCIPAL_ID
```

## Security Recommendations

### 1. Use Managed Identity
- **Recommended**: Enable System-Assigned Managed Identity for App Service
- **Benefit**: Eliminates need to store credentials
- **Implementation**: The Bicep/Terraform templates automatically enable managed identity
- **Usage**: Use `DefaultAzureCredential` in application code (see samples)

### 2. Secrets Management
- **Never commit secrets** to source control
- **Use Azure Key Vault** for all application secrets
- **Use Pipeline Secret Variables** for deployment secrets (e.g., SQL_ADMIN_PASSWORD)
- **Rotate secrets regularly**

### 3. Least Privilege Access
- Grant minimum required permissions to service principals
- Use resource-level role assignments instead of subscription-level
- Review and audit access regularly

### 4. Network Security
- **Enable Private Endpoints** for production workloads
- **Configure VNet integration** for App Service
- **Restrict ACR access** to specific networks
- **Use Application Gateway** or Front Door for internet-facing apps

### 5. SQL Security
- **Use Azure AD authentication** when possible
- **Enable TLS 1.2** minimum (configured in templates)
- **Configure firewall rules** appropriately
- **Enable Advanced Threat Protection** for production

### 6. Monitoring and Compliance
- **Application Insights** for application monitoring (configured)
- **Azure Security Center** recommendations
- **Enable diagnostic logs** for all resources
- **Set up alerts** for critical events

## Pipeline Variables Reference

### Required Service Connection
Create in Azure DevOps Project Settings > Service Connections:
- Type: Azure Resource Manager
- Name: Set as value of `AZURE_SERVICE_CONNECTION` variable

### Required Pipeline Variables
Set in Azure DevOps Pipeline > Variables:

```yaml
# Service Connection
AZURE_SERVICE_CONNECTION: 'azure-service-connection'

# Resource Configuration
RG_NAME: 'rg-brettappscode-prod'
LOCATION: 'eastus'

# Container Registry
ACR_NAME: 'brettappsacr'
IMAGE_NAME: 'brettappscode'

# App Service
APP_SERVICE_NAME: 'brettappscode-webapp'

# Key Vault
KEY_VAULT_NAME: 'brettappskv'

# SQL Database
SQL_SERVER_NAME: 'brettappssql'
SQL_DB_NAME: 'brettappscode-db'
SQL_ADMIN_PASSWORD: '***' # Secret variable

# Monitoring
APP_INSIGHTS_NAME: 'brettapps-ai'
```

## Infrastructure Deployment Options

### Option 1: Bicep (Recommended for Azure-native)
Located in `iac/bicep/main.bicep`

**Deploy manually:**
```bash
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
    sqlAdminPassword=<PASSWORD>
```

### Option 2: Terraform
Located in `iac/terraform/main.tf`

**Deploy manually:**
```bash
cd iac/terraform
terraform init
terraform plan
terraform apply
```

**Required variables** (create `terraform.tfvars`):
```hcl
resource_group_name = "rg-brettappscode-prod"
location            = "eastus"
acr_name            = "brettappsacr"
app_service_name    = "brettappscode-webapp"
key_vault_name      = "brettappskv"
sql_server_name     = "brettappssql"
sql_db_name         = "brettappscode-db"
sql_admin_password  = "YourStr0ngP@ssw0rd!"
app_insights_name   = "brettapps-ai"
```

## Application Code Integration

### Key Vault Access (Node.js)
See `src/samples/keyvault-nodejs.md` for complete examples.

**Using Managed Identity:**
```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

const credential = new DefaultAzureCredential();
const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
const client = new SecretClient(vaultUrl, credential);

const secret = await client.getSecret("my-secret");
```

### Application Insights
Already configured in App Service settings. Install SDK:
```bash
npm install applicationinsights
```

```javascript
const appInsights = require("applicationinsights");
appInsights.setup().start();
```

## Troubleshooting

### Pipeline Fails at Docker Build
- Verify ACR name is globally unique
- Check service connection has permission to access ACR
- Ensure ACR admin user is enabled

### Pipeline Fails at Infrastructure Deploy
- Verify all resource names are globally unique
- Check service principal has Contributor role
- Ensure resource providers are registered in subscription

### App Service Returns 503
- Check container logs: `az webapp log tail --name <APP_NAME> --resource-group <RG_NAME>`
- Verify `WEBSITES_PORT` is set to `3000`
- Check Docker image is pushed successfully to ACR

### Key Vault Access Denied
- Verify managed identity is enabled on App Service
- Check access policy grants `Get` and `List` permissions
- Ensure application is using `DefaultAzureCredential`

## Adapting for Other Runtimes

This setup is configured for Node.js 18. To adapt for other runtimes:

### Python
- Update `build.yml` to use `UsePythonVersion` task
- Modify Dockerfile to use Python base image
- Update `package.json` references to `requirements.txt`

### .NET / C#
- Update `build.yml` to use `UseDotNet` task
- Modify Dockerfile to use .NET SDK and runtime images
- Update build commands for `dotnet restore`, `dotnet build`, `dotnet publish`

### Azure Functions
- Use Azure Functions deployment templates instead of App Service
- Update pipeline to use Azure Functions tasks
- Modify IaC templates to create Function App instead of Web App

## Additional Resources

- [Azure Pipelines Documentation](https://docs.microsoft.com/azure/devops/pipelines/)
- [Azure Container Registry](https://docs.microsoft.com/azure/container-registry/)
- [App Service for Containers](https://docs.microsoft.com/azure/app-service/quickstart-custom-container)
- [Azure Key Vault](https://docs.microsoft.com/azure/key-vault/)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Notes for Repository Owner

**Important**: This integration setup requires customization:

1. **Update resource names** to match your naming conventions and ensure global uniqueness
2. **Configure service connections** in your Azure DevOps project
3. **Set pipeline variables** with your actual values
4. **Review security settings** and adjust based on your security requirements
5. **Adapt for your runtime** if not using Node.js
6. **Consider Functions-first** architecture if serverless is preferred
7. **No credentials are included** - you must configure all secrets and passwords

**Do not merge** this PR until you have:
- Reviewed all files and configurations
- Updated names and values for your environment
- Tested the pipeline in a non-production environment
- Verified security settings meet your requirements
- Adapted templates for your specific needs (if not using Node.js)

## Support

For issues related to:
- **Azure DevOps**: Contact your Azure DevOps administrator
- **Azure Resources**: Check Azure documentation or open a support ticket
- **Application Code**: See main repository README and application documentation
