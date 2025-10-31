# Azure Integration - Quick Start

This document provides a quick start guide for the Azure integration in this repository.

## What's Included

This branch (`azure/integration`) adds complete Azure integration with:

- ✅ Multi-stage Azure DevOps CI/CD pipeline
- ✅ Infrastructure as Code (Bicep and Terraform)
- ✅ Docker containerization
- ✅ Azure Container Registry integration
- ✅ App Service (Web App for Containers) deployment
- ✅ Azure Key Vault for secrets management
- ✅ Azure SQL Database
- ✅ Azure Storage Account
- ✅ Application Insights monitoring
- ✅ Managed Identity configuration
- ✅ Comprehensive documentation and code samples

## Quick Start

### 1. Prerequisites

- Azure subscription with appropriate permissions
- Azure DevOps organization and project
- Azure CLI installed (for local testing)

### 2. Setup Steps

1. **Create Azure Service Connection**
   - In Azure DevOps: Project Settings → Service connections → New service connection
   - Choose "Azure Resource Manager"
   - Name it (e.g., `azure-service-connection`)

2. **Configure Pipeline Variables**
   - In Azure DevOps: Pipelines → Edit → Variables
   - Add all required variables (see docs/AZURE-INTEGRATION.md for full list)
   - Mark `SQL_ADMIN_PASSWORD` as secret

3. **Run the Pipeline**
   - Azure DevOps will automatically detect `azure-pipelines.yml`
   - Click Run to deploy infrastructure and application

### 3. Required Pipeline Variables

| Variable | Example | Secret? |
|----------|---------|---------|
| AZURE_SERVICE_CONNECTION | `azure-service-connection` | No |
| RG_NAME | `rg-brettappscode-prod` | No |
| LOCATION | `eastus` | No |
| ACR_NAME | `acrbrettappscode` | No |
| IMAGE_NAME | `brettappscode` | No |
| APP_SERVICE_NAME | `app-brettappscode` | No |
| KEY_VAULT_NAME | `kv-brettappscode` | No |
| SQL_SERVER_NAME | `sql-brettappscode` | No |
| SQL_DB_NAME | `brettappscode-db` | No |
| APP_INSIGHTS_NAME | `appi-brettappscode` | No |
| SQL_ADMIN_PASSWORD | `YourSecurePassword123!` | **Yes** |

**Note:** Names for ACR, App Service, Key Vault, and SQL Server must be globally unique.

## Documentation

For detailed setup instructions, troubleshooting, and configuration:

📖 **[Full Documentation: docs/AZURE-INTEGRATION.md](docs/AZURE-INTEGRATION.md)**

## Code Samples

Sample Node.js code for Azure Key Vault integration:

📝 **[Key Vault Node.js Sample: src/samples/keyvault-nodejs.md](src/samples/keyvault-nodejs.md)**

## Pipeline Stages

1. **Build** - Build and test Node.js application
2. **DeployInfrastructure** - Deploy Azure resources using Bicep
3. **DockerBuildPush** - Build and push Docker image to ACR
4. **DeployAppService** - Deploy to Web App for Containers
5. **PostDeploy** - Database migrations and smoke tests

## Infrastructure as Code

Choose between two IaC options:

### Option 1: Bicep (Default)
- Template: `iac/bicep/main.bicep`
- Used by default in the pipeline

### Option 2: Terraform (Alternative)
- Template: `iac/terraform/main.tf`
- See documentation for Terraform setup instructions

## Security Features

- ✅ Managed Identity for App Service
- ✅ Key Vault for secret storage
- ✅ HTTPS-only enforcement
- ✅ Non-root Docker container
- ✅ No secrets in code
- ✅ TLS 1.2 minimum

## Support

For issues or questions, refer to:
1. [docs/AZURE-INTEGRATION.md](docs/AZURE-INTEGRATION.md) - Full documentation
2. Azure DevOps pipeline logs
3. Azure Portal for resource status
4. Open an issue in this repository

---

**Ready to Deploy?** Follow the setup steps above and run the pipeline!
