# Azure Integration Documentation

This document provides comprehensive guidance for deploying and managing BrettAppsCode on Microsoft Azure using Azure DevOps Pipelines, Azure Container Registry (ACR), Azure App Service, Azure Kubernetes Service (AKS), Azure Key Vault, Azure SQL Database, and Application Insights.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Azure Resources](#azure-resources)
4. [Pipeline Configuration](#pipeline-configuration)
5. [Infrastructure as Code](#infrastructure-as-code)
6. [Security Best Practices](#security-best-practices)
7. [Deployment Steps](#deployment-steps)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Troubleshooting](#troubleshooting)

## Overview

This application is designed to be deployed on Azure using a comprehensive CI/CD pipeline that includes:

- **Build & Test**: Automated builds and tests for Node.js application
- **Containerization**: Docker image build and push to Azure Container Registry
- **Infrastructure Deployment**: Automated infrastructure provisioning using Bicep or Terraform
- **Application Deployment**: Deploy to Azure App Service or Azure Kubernetes Service
- **Security**: Managed identities, Key Vault integration, and secure secret management

## Prerequisites

### Azure Requirements

1. **Azure Subscription**: Active Azure subscription with appropriate permissions
2. **Azure DevOps Organization**: Azure DevOps organization and project
3. **Service Connection**: Azure Resource Manager service connection in Azure DevOps
4. **Resource Naming**: Ensure all resource names are globally unique (ACR, Key Vault, SQL Server, etc.)

### Local Development Requirements

- Azure CLI (`az cli`) version 2.40+
- Node.js 18.x or higher
- Docker Desktop (for local container builds)
- Bicep CLI (for IaC deployment)
- Terraform CLI (optional, for Terraform IaC)

### Required Permissions

The Azure service principal or managed identity needs the following permissions:

- **Subscription Level**: Contributor role (or custom role with specific permissions)
- **Resource Group**: Create and manage resources
- **Azure DevOps**: Pipeline administrator access

## Azure Resources

### Core Resources Deployed

1. **Azure Container Registry (ACR)**
   - SKU: Basic
   - Purpose: Store Docker images
   - Authentication: Managed Identity (no admin user)

2. **App Service Plan**
   - SKU: B1 (Basic)
   - OS: Linux
   - Purpose: Host the containerized application

3. **App Service (Web App)**
   - Runtime: Docker Container
   - System-Assigned Managed Identity: Enabled
   - HTTPS Only: Enabled
   - TLS Version: 1.2+

4. **Azure Key Vault**
   - SKU: Standard
   - Soft Delete: Enabled (90 days retention)
   - Purge Protection: Enabled
   - Access: Azure RBAC enabled
   - Purpose: Store secrets, connection strings, API keys

5. **Azure SQL Database**
   - SKU: Basic
   - TLS Version: 1.2+
   - Azure AD Authentication: Enabled
   - Purpose: Application database

6. **Application Insights**
   - Type: Web
   - Purpose: Application monitoring, logging, and telemetry

7. **Log Analytics Workspace**
   - SKU: PerGB2018
   - Retention: 30 days
   - Purpose: Centralized logging for Application Insights

### Resource Naming Conventions

All resources follow Azure naming best practices:

- **ACR**: `<prefix>acr<env>` (e.g., `brettacr01`)
- **App Service**: `<prefix>-app-<env>` (e.g., `brett-app-prod`)
- **Key Vault**: `<prefix>-kv-<env>` (e.g., `brett-kv-prod`)
- **SQL Server**: `<prefix>-sql-<env>` (e.g., `brett-sql-prod`)
- **App Insights**: `<prefix>-ai-<env>` (e.g., `brett-ai-prod`)

## Pipeline Configuration

### Required Pipeline Variables

Configure the following variables in Azure DevOps (Pipeline → Variables):

#### Service Connection
- `AZURE_SERVICE_CONNECTION`: Name of the Azure Resource Manager service connection

#### Resource Configuration
- `RG_NAME`: Resource group name (e.g., `brettappscode-rg`)
- `LOCATION`: Azure region (e.g., `eastus`, `westus2`, `westeurope`)

#### Resource Names
- `ACR_NAME`: Azure Container Registry name (must be globally unique, alphanumeric only)
- `IMAGE_NAME`: Docker image name (e.g., `brettappscode`)
- `APP_SERVICE_NAME`: App Service name (must be globally unique)
- `KEY_VAULT_NAME`: Key Vault name (must be globally unique, 3-24 chars)
- `SQL_SERVER_NAME`: SQL Server name (must be globally unique)
- `SQL_DB_NAME`: SQL Database name (e.g., `brettappsdb`)
- `APP_INSIGHTS_NAME`: Application Insights name

#### Secrets (Store in Azure DevOps as Secret Variables)
- `SQL_ADMIN_PASSWORD`: SQL Server administrator password (mark as secret)
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID (optional, for explicit subscription targeting)

### Pipeline Stages

1. **Build**: Compile, test, and validate the application
2. **DockerBuild**: Build and push Docker image to ACR
3. **InfrastructureDeployment**: Deploy Azure infrastructure using Bicep
4. **DeployAppService**: Deploy containerized app to App Service
5. **DeployAKS**: (Optional) Deploy to Azure Kubernetes Service

### Triggering the Pipeline

The pipeline triggers automatically on:
- Commits to `main`, `develop`, or `azure/integration` branches
- Pull requests targeting `main` or `develop`
- Excludes changes to README and docs

Manual triggers are also supported via Azure DevOps UI.

## Infrastructure as Code

### Bicep Deployment

Bicep is the recommended IaC tool for Azure. It provides:
- Native Azure support
- Strong typing and IntelliSense
- Simpler syntax than ARM templates
- Native Azure CLI integration

**Deployment Command:**
```bash
az deployment group create \
  --resource-group <RG_NAME> \
  --template-file iac/bicep/main.bicep \
  --parameters \
    location=<LOCATION> \
    acrName=<ACR_NAME> \
    appServiceName=<APP_SERVICE_NAME> \
    keyVaultName=<KEY_VAULT_NAME> \
    sqlServerName=<SQL_SERVER_NAME> \
    sqlDatabaseName=<SQL_DB_NAME> \
    appInsightsName=<APP_INSIGHTS_NAME> \
    sqlAdminPassword=<SQL_ADMIN_PASSWORD>
```

### Terraform Deployment

Terraform is an alternative IaC option for multi-cloud scenarios.

**Deployment Commands:**
```bash
cd iac/terraform

# Initialize Terraform
terraform init

# Plan deployment (preview changes)
terraform plan \
  -var="resource_group_name=<RG_NAME>" \
  -var="location=<LOCATION>" \
  -var="acr_name=<ACR_NAME>" \
  -var="app_service_name=<APP_SERVICE_NAME>" \
  -var="key_vault_name=<KEY_VAULT_NAME>" \
  -var="sql_server_name=<SQL_SERVER_NAME>" \
  -var="sql_database_name=<SQL_DB_NAME>" \
  -var="app_insights_name=<APP_INSIGHTS_NAME>" \
  -var="sql_admin_password=<SQL_ADMIN_PASSWORD>"

# Apply deployment
terraform apply
```

## Security Best Practices

### 1. Managed Identities

**Always use managed identities instead of connection strings or service principals:**

- App Service has a **system-assigned managed identity** enabled by default
- The managed identity is granted:
  - `AcrPull` role on ACR (to pull container images)
  - `Key Vault Secrets User` role on Key Vault (to read secrets)
- No credentials are stored in code or configuration

### 2. Key Vault Integration

**Store all secrets in Azure Key Vault:**

```bash
# Add secrets to Key Vault
az keyvault secret set --vault-name <KEY_VAULT_NAME> --name "ApiKey" --value "<YOUR_API_KEY>"
az keyvault secret set --vault-name <KEY_VAULT_NAME> --name "DatabaseConnectionString" --value "<CONNECTION_STRING>"
```

**Reference secrets in App Service:**

App Service settings can reference Key Vault secrets using this format:
```
@Microsoft.KeyVault(SecretUri=https://<KEY_VAULT_NAME>.vault.azure.net/secrets/<SECRET_NAME>/)
```

Example:
```bash
az webapp config appsettings set \
  --name <APP_SERVICE_NAME> \
  --resource-group <RG_NAME> \
  --settings \
    ApiKey="@Microsoft.KeyVault(SecretUri=https://<KEY_VAULT_NAME>.vault.azure.net/secrets/ApiKey/)"
```

### 3. Least Privilege Access

- Grant only the minimum required permissions
- Use Azure RBAC for Key Vault (not access policies)
- Enable Azure AD authentication for SQL Server
- Review and audit role assignments regularly

### 4. Network Security

**Production Recommendations:**

- Enable **Private Endpoints** for Key Vault, SQL Server, and ACR
- Configure **Virtual Network Integration** for App Service
- Set Key Vault network rules to deny public access
- Use **Azure Firewall** or **NSGs** for network segmentation

### 5. Secret Management

**Never commit secrets to source control:**

- Use pipeline secret variables for sensitive data
- Rotate secrets regularly
- Enable Key Vault audit logging
- Use separate Key Vaults for different environments (dev, staging, prod)

### 6. TLS/SSL Configuration

- HTTPS Only: Enforced on App Service
- Minimum TLS Version: 1.2
- Consider using Azure Front Door or Application Gateway for TLS termination

### 7. SQL Database Security

- Enable **Azure AD authentication** (configured in Bicep/Terraform)
- Disable SQL authentication if not needed
- Use **firewall rules** to restrict access
- Enable **Transparent Data Encryption (TDE)** (enabled by default)
- Enable **Advanced Threat Protection**

## Deployment Steps

### Step 1: Create Azure DevOps Pipeline

1. Navigate to Azure DevOps → Pipelines → New Pipeline
2. Select your repository
3. Choose "Existing Azure Pipelines YAML file"
4. Select `/azure-pipelines.yml`
5. Click "Run" (it will fail until variables are configured)

### Step 2: Configure Pipeline Variables

1. Go to Pipeline → Edit → Variables
2. Add all required variables (see [Pipeline Configuration](#pipeline-configuration))
3. Mark `SQL_ADMIN_PASSWORD` as secret
4. Save the pipeline

### Step 3: Create Azure Service Connection

1. Azure DevOps → Project Settings → Service Connections
2. New Service Connection → Azure Resource Manager
3. Select "Service principal (automatic)"
4. Choose subscription and resource group
5. Name it (e.g., `azure-service-connection`)
6. Grant necessary permissions

### Step 4: Run the Pipeline

1. Go to Pipelines → Run Pipeline
2. Select branch (e.g., `azure/integration` or `main`)
3. Click "Run"
4. Monitor the pipeline execution

### Step 5: Verify Deployment

After successful deployment:

```bash
# Check App Service status
az webapp show --name <APP_SERVICE_NAME> --resource-group <RG_NAME>

# Get App Service URL
az webapp show --name <APP_SERVICE_NAME> --resource-group <RG_NAME> --query defaultHostName -o tsv

# Test the application
curl https://<APP_SERVICE_URL>
```

## Monitoring and Observability

### Application Insights

Application Insights is automatically configured and provides:

- **Request telemetry**: HTTP requests, response times, failures
- **Dependency tracking**: Database calls, external API calls
- **Exception tracking**: Unhandled exceptions and errors
- **Custom events and metrics**: Application-specific telemetry

**View Application Insights:**
```bash
# Open in Azure Portal
az monitor app-insights component show \
  --app <APP_INSIGHTS_NAME> \
  --resource-group <RG_NAME> \
  --query "appId" -o tsv
```

### Log Streaming

**Stream App Service logs:**
```bash
az webapp log tail --name <APP_SERVICE_NAME> --resource-group <RG_NAME>
```

### Metrics and Alerts

Configure alerts for:
- High CPU usage
- High memory usage
- HTTP 5xx errors
- Failed requests
- Slow response times

## Troubleshooting

### Issue: Pipeline Fails at Docker Build

**Possible Causes:**
- ACR name is not globally unique
- Service connection doesn't have ACR push permissions

**Solution:**
```bash
# Verify ACR name availability
az acr check-name --name <ACR_NAME>

# Grant AcrPush role to service principal
az role assignment create \
  --assignee <SERVICE_PRINCIPAL_ID> \
  --role AcrPush \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.ContainerRegistry/registries/<ACR_NAME>
```

### Issue: App Service Can't Pull Image

**Possible Causes:**
- Managed identity doesn't have AcrPull permission
- ACR admin user is enabled (should be disabled)

**Solution:**
```bash
# Grant AcrPull to App Service managed identity
PRINCIPAL_ID=$(az webapp identity show --name <APP_SERVICE_NAME> --resource-group <RG_NAME> --query principalId -o tsv)

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role AcrPull \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.ContainerRegistry/registries/<ACR_NAME>
```

### Issue: Key Vault Access Denied

**Possible Causes:**
- Managed identity doesn't have Key Vault permissions
- Key Vault firewall blocking access

**Solution:**
```bash
# Grant Key Vault Secrets User role
PRINCIPAL_ID=$(az webapp identity show --name <APP_SERVICE_NAME> --resource-group <RG_NAME> --query principalId -o tsv)

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.KeyVault/vaults/<KEY_VAULT_NAME>
```

### Issue: SQL Database Connection Fails

**Possible Causes:**
- Firewall rules not configured
- Connection string incorrect
- Azure AD authentication not configured

**Solution:**
```bash
# Add firewall rule for Azure services
az sql server firewall-rule create \
  --resource-group <RG_NAME> \
  --server <SQL_SERVER_NAME> \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### Issue: App Service Shows 503 Error

**Possible Causes:**
- Container failed to start
- Health check failing
- Application code error

**Solution:**
```bash
# Check container logs
az webapp log tail --name <APP_SERVICE_NAME> --resource-group <RG_NAME>

# Check container status
az webapp show --name <APP_SERVICE_NAME> --resource-group <RG_NAME> --query state
```

## Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/azure/container-registry/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure SQL Database Documentation](https://docs.microsoft.com/azure/azure-sql/)
- [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review pipeline logs in Azure DevOps
3. Check Application Insights for application errors
4. Open an issue in the repository

---

**Last Updated:** 2025-10-31  
**Version:** 1.0.0
