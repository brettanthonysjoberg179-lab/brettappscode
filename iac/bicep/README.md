# Bicep Infrastructure as Code

This directory contains Bicep templates to deploy the BrettAppsCode application infrastructure to Microsoft Azure.

## Files

- `main.bicep` - Main Bicep template with all resource definitions

## Prerequisites

1. [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
2. [Bicep CLI](https://docs.microsoft.com/azure/azure-resource-manager/bicep/install) installed (or use Azure CLI >= 2.20.0)
3. Azure subscription with appropriate permissions

## Quick Start

### 1. Authenticate with Azure

```bash
az login
```

Set your subscription if you have multiple:

```bash
az account set --subscription "Your Subscription Name"
```

### 2. Create Resource Group

```bash
az group create \
  --name brettappscode-rg \
  --location eastus
```

### 3. Deploy Bicep Template

#### Option A: Interactive Deployment

Deploy with interactive prompts for parameters:

```bash
az deployment group create \
  --resource-group brettappscode-rg \
  --template-file main.bicep
```

#### Option B: Inline Parameters

Deploy with parameters provided inline:

```bash
az deployment group create \
  --resource-group brettappscode-rg \
  --template-file main.bicep \
  --parameters \
    acrName=brettappsacr \
    appServiceName=brettappscode-app \
    keyVaultName=brettappskv \
    sqlServerName=brettappscode-sql \
    sqlDatabaseName=brettappsdb \
    sqlAdminPassword='YourSecurePassword123!' \
    appInsightsName=brettappscode-insights \
    location=eastus
```

#### Option C: Parameters File

Create a `parameters.json` file:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "acrName": {
      "value": "brettappsacr"
    },
    "appServiceName": {
      "value": "brettappscode-app"
    },
    "keyVaultName": {
      "value": "brettappskv"
    },
    "sqlServerName": {
      "value": "brettappscode-sql"
    },
    "sqlDatabaseName": {
      "value": "brettappsdb"
    },
    "sqlAdminPassword": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}"
        },
        "secretName": "sqlAdminPassword"
      }
    },
    "appInsightsName": {
      "value": "brettappscode-insights"
    },
    "location": {
      "value": "eastus"
    }
  }
}
```

Deploy with parameters file:

```bash
az deployment group create \
  --resource-group brettappscode-rg \
  --template-file main.bicep \
  --parameters parameters.json
```

**Note**: Do not commit `parameters.json` with sensitive data to source control.

### 4. View Deployment Outputs

```bash
az deployment group show \
  --resource-group brettappscode-rg \
  --name main \
  --query properties.outputs
```

Or get a specific output:

```bash
az deployment group show \
  --resource-group brettappscode-rg \
  --name main \
  --query properties.outputs.webAppUrl.value \
  --output tsv
```

## Bicep Commands

### Validate Template

Check for syntax errors:

```bash
az deployment group validate \
  --resource-group brettappscode-rg \
  --template-file main.bicep \
  --parameters acrName=brettappsacr appServiceName=brettappscode-app keyVaultName=brettappskv sqlServerName=brettappscode-sql sqlDatabaseName=brettappsdb sqlAdminPassword='YourSecurePassword123!' appInsightsName=brettappscode-insights
```

### What-If Analysis

Preview changes before deployment:

```bash
az deployment group what-if \
  --resource-group brettappscode-rg \
  --template-file main.bicep \
  --parameters acrName=brettappsacr appServiceName=brettappscode-app keyVaultName=brettappskv sqlServerName=brettappscode-sql sqlDatabaseName=brettappsdb sqlAdminPassword='YourSecurePassword123!' appInsightsName=brettappscode-insights
```

### Build Bicep to ARM Template

Convert Bicep to ARM JSON template:

```bash
az bicep build --file main.bicep
```

This creates `main.json` with the ARM template.

### Decompile ARM to Bicep

Convert existing ARM template to Bicep:

```bash
az bicep decompile --file template.json
```

### Upgrade Bicep

```bash
az bicep upgrade
```

## Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `location` | string | Azure region | `eastus`, `westus2` |
| `acrName` | string | Container Registry name (alphanumeric only) | `brettappsacr` |
| `appServiceName` | string | App Service name | `brettappscode-app` |
| `appServicePlanName` | string | App Service Plan name (auto-generated if not provided) | `brettappscode-app-plan` |
| `keyVaultName` | string | Key Vault name (3-24 chars) | `brettappskv` |
| `sqlServerName` | string | SQL Server name | `brettappscode-sql` |
| `sqlDatabaseName` | string | SQL Database name | `brettappsdb` |
| `sqlAdminLogin` | string | SQL admin username | `sqladmin` |
| `sqlAdminPassword` | securestring | SQL admin password (min 8 chars) | `YourSecurePassword123!` |
| `storageAccountName` | string | Storage Account name (auto-generated if not provided) | `brettappsst` |
| `appInsightsName` | string | Application Insights name | `brettappscode-insights` |
| `logAnalyticsName` | string | Log Analytics Workspace name (auto-generated if not provided) | `brettappscode-app-logs` |
| `appServicePlanSku` | string | App Service Plan SKU | `B1`, `S1`, `P1V2` |
| `sqlDatabaseSku` | string | SQL Database SKU | `Basic`, `Standard`, `Premium` |

## Outputs

After deployment, the following outputs are available:

- `acrLoginServer` - ACR login server URL
- `acrName` - ACR name
- `appServiceName` - App Service name
- `webAppUrl` - Application URL (https)
- `appServicePrincipalId` - Managed Identity principal ID
- `keyVaultName` - Key Vault name
- `keyVaultUri` - Key Vault URI
- `sqlServerFqdn` - SQL Server FQDN
- `sqlDatabaseName` - SQL Database name
- `storageAccountName` - Storage Account name
- `storageAccountPrimaryEndpoint` - Blob storage endpoint
- `appInsightsName` - Application Insights name
- `appInsightsInstrumentationKey` - App Insights instrumentation key
- `appInsightsConnectionString` - App Insights connection string
- `logAnalyticsWorkspaceId` - Log Analytics Workspace ID

## Resource Naming

Ensure your resource names comply with Azure naming conventions:

- **ACR**: 5-50 characters, alphanumeric only, globally unique
- **App Service**: 2-60 characters, alphanumeric and hyphens
- **Key Vault**: 3-24 characters, alphanumeric and hyphens, must start with letter, globally unique
- **SQL Server**: 1-63 characters, lowercase, alphanumeric and hyphens, globally unique
- **Storage Account**: 3-24 characters, lowercase alphanumeric only, globally unique

## Managing Secrets

### Using Key Vault Reference

For sensitive parameters like `sqlAdminPassword`, reference an existing Key Vault secret:

```json
{
  "sqlAdminPassword": {
    "reference": {
      "keyVault": {
        "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{vault}"
      },
      "secretName": "sqlAdminPassword"
    }
  }
}
```

### Using Azure DevOps Pipeline Variables

In Azure Pipelines, use secure variables:

```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'MyServiceConnection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      az deployment group create \
        --resource-group $(RG_NAME) \
        --template-file main.bicep \
        --parameters sqlAdminPassword='$(SQL_ADMIN_PASSWORD)'
```

## Update Existing Deployment

Bicep deployments are idempotent. Re-run the deployment command to update:

```bash
az deployment group create \
  --resource-group brettappscode-rg \
  --template-file main.bicep \
  --parameters ...
```

Only changed resources will be updated.

## Delete Resources

### Delete Resource Group

```bash
az group delete --name brettappscode-rg --yes
```

**Warning**: This permanently deletes all resources in the resource group.

### Delete Specific Resources

Use Azure Portal or Azure CLI to delete individual resources.

## Cost Estimation

Approximate monthly costs with basic tier resources:

- Azure Container Registry (Basic): $5
- App Service Plan (B1): $13
- Azure SQL Database (Basic): $5
- Storage Account (Standard LRS): $2
- Application Insights: Pay-as-you-go (~$2-5)
- Key Vault: $0.03 per 10k operations
- Log Analytics: Pay-as-you-go (~$2)

**Total**: ~$27-32/month

Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for accurate estimates.

## Best Practices

1. **Use Parameter Files**: Store parameters in separate files (not in source control if sensitive)
2. **Enable Soft Delete**: Key Vault soft delete is enabled by default (90 days retention)
3. **Use Managed Identity**: App Service uses system-assigned managed identity
4. **HTTPS Only**: Enforced for App Service
5. **TLS 1.2**: Minimum TLS version enforced
6. **Firewall Rules**: Configure SQL Server firewall appropriately
7. **Resource Locks**: Consider adding locks to prevent accidental deletion
8. **Tags**: Use resource tags for organization and cost tracking

## Troubleshooting

### Deployment Failures

View deployment errors:

```bash
az deployment group show \
  --resource-group brettappscode-rg \
  --name main
```

### Validation Errors

```bash
az deployment group validate \
  --resource-group brettappscode-rg \
  --template-file main.bicep \
  --parameters ...
```

### Name Conflicts

If resources with the same name already exist globally, choose different names.

### Quotas and Limits

Check subscription quotas:

```bash
az vm list-usage --location eastus --output table
```

## Bicep vs ARM Templates

Bicep advantages:
- Cleaner, more concise syntax
- Better tooling support (VS Code extension)
- No state file management (unlike Terraform)
- Native Azure support
- Automatically handles dependencies

## CI/CD Integration

### Azure Pipelines

The pipeline template `.pipelines/iac-deploy-bicep.yml` handles Bicep deployment automatically.

### GitHub Actions

Example workflow:

```yaml
- name: Deploy Bicep
  uses: azure/CLI@v1
  with:
    inlineScript: |
      az deployment group create \
        --resource-group ${{ env.RG_NAME }} \
        --template-file iac/bicep/main.bicep \
        --parameters \
          acrName=${{ env.ACR_NAME }} \
          appServiceName=${{ env.APP_SERVICE_NAME }} \
          sqlAdminPassword=${{ secrets.SQL_ADMIN_PASSWORD }}
```

## Additional Resources

- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Bicep Playground](https://aka.ms/bicepdemo)
- [Bicep VS Code Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)
- [Azure Resource Manager Templates](https://docs.microsoft.com/azure/azure-resource-manager/templates/)
- [Azure Quickstart Templates](https://azure.microsoft.com/resources/templates/)

## Support

For issues or questions:
- [Bicep GitHub Issues](https://github.com/Azure/bicep/issues)
- [Azure Documentation](https://docs.microsoft.com/azure/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/azure-bicep)
