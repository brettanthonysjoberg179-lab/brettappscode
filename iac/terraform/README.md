# Terraform Infrastructure as Code

This directory contains Terraform configuration files to deploy the BrettAppsCode application infrastructure to Microsoft Azure.

## Files

- `main.tf` - Main Terraform configuration with all resource definitions
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars.example` - Example variables file (copy to `terraform.tfvars`)

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) >= 1.0 installed
2. [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
3. Azure subscription with appropriate permissions

## Quick Start

### 1. Authenticate with Azure

```bash
az login
```

### 2. Initialize Terraform

```bash
terraform init
```

This will download the required Azure provider plugins.

### 3. Create Variables File

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired values:

```hcl
resource_group_name  = "brettappscode-rg"
location            = "eastus"
acr_name            = "brettappsacr"
app_service_name    = "brettappscode-app"
key_vault_name      = "brettappskv"
sql_server_name     = "brettappscode-sql"
sql_database_name   = "brettappsdb"
sql_admin_login     = "sqladmin"
sql_admin_password  = "YourSecurePassword123!"
storage_account_name = "brettappsst"
app_insights_name   = "brettappscode-insights"
```

**Important**: 
- ACR names must be globally unique and alphanumeric only
- Key Vault names must be globally unique, 3-24 characters
- Storage account names must be globally unique, 3-24 lowercase alphanumeric characters
- SQL password must be at least 8 characters with complexity requirements

### 4. Plan Deployment

Review the resources that will be created:

```bash
terraform plan
```

Or save the plan to a file:

```bash
terraform plan -out=tfplan
```

### 5. Apply Configuration

Deploy the infrastructure:

```bash
terraform apply
```

Or use the saved plan:

```bash
terraform apply tfplan
```

Type `yes` when prompted to confirm.

### 6. View Outputs

After deployment, view the outputs:

```bash
terraform output
```

To get a specific output:

```bash
terraform output app_service_url
```

## Managing Secrets

### Using Environment Variables

Instead of storing sensitive values in `terraform.tfvars`, use environment variables:

```bash
export TF_VAR_sql_admin_password="YourSecurePassword123!"
terraform apply
```

### Using Azure Key Vault for Backend State

For team environments, configure remote state storage:

1. Create a storage account for Terraform state:

```bash
# Create resource group
az group create --name terraform-state-rg --location eastus

# Create storage account
az storage account create \
  --name tfstatestorage \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name tfstatestorage
```

2. Update `main.tf` backend configuration (uncomment the backend block):

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatestorage"
    container_name       = "tfstate"
    key                  = "brettappscode.terraform.tfstate"
  }
}
```

3. Re-initialize Terraform:

```bash
terraform init -migrate-state
```

## Common Commands

| Command | Description |
|---------|-------------|
| `terraform init` | Initialize Terraform working directory |
| `terraform plan` | Preview changes |
| `terraform apply` | Apply changes |
| `terraform destroy` | Destroy all resources |
| `terraform validate` | Validate configuration |
| `terraform fmt` | Format configuration files |
| `terraform show` | Show current state |
| `terraform output` | Display outputs |
| `terraform state list` | List resources in state |

## Resource Naming

Ensure your resource names comply with Azure naming conventions:

- **Resource Group**: 1-90 characters, alphanumeric, underscores, hyphens, periods
- **ACR**: 5-50 characters, alphanumeric only
- **App Service**: 2-60 characters, alphanumeric and hyphens
- **Key Vault**: 3-24 characters, alphanumeric and hyphens, must start with letter
- **SQL Server**: 1-63 characters, lowercase, alphanumeric and hyphens
- **Storage Account**: 3-24 characters, lowercase alphanumeric only

## Cost Estimation

Approximate monthly costs with basic tier resources:

- Azure Container Registry (Basic): $5
- App Service Plan (B1): $13
- Azure SQL Database (Basic): $5
- Storage Account (Standard LRS): $2
- Application Insights: Pay-as-you-go (~$2-5)
- Key Vault: $0.03 per 10k operations

**Total**: ~$25-30/month

Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for accurate estimates.

## Cleanup

To delete all resources:

```bash
terraform destroy
```

Review the resources to be deleted and type `yes` to confirm.

**Warning**: This will permanently delete all resources including databases and data. Ensure you have backups if needed.

## Troubleshooting

### Authentication Issues

```bash
az login
az account show
az account set --subscription "Your Subscription Name"
```

### Resource Name Conflicts

If you get errors about existing resources, choose different unique names.

### Provider Plugin Errors

```bash
terraform init -upgrade
```

### State Lock Issues

If state is locked and you're sure no other operation is running:

```bash
terraform force-unlock <LOCK_ID>
```

## Advanced Configuration

### Using Workspaces

Manage multiple environments with workspaces:

```bash
# Create production workspace
terraform workspace new production

# Create development workspace
terraform workspace new development

# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select production
```

### Module Variables by Environment

Create separate `.tfvars` files for each environment:

```bash
terraform apply -var-file="production.tfvars"
terraform apply -var-file="development.tfvars"
```

## Security Best Practices

1. **Never commit `terraform.tfvars`** with sensitive data (add to `.gitignore`)
2. Use **Azure Key Vault** to store secrets
3. Enable **Managed Identity** for App Service (already configured)
4. Use **remote state** with encryption
5. Enable **state locking** to prevent concurrent modifications
6. Review **Terraform plan** before applying changes
7. Use **least privilege** for service principals

## Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Naming Conventions](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## Support

For issues or questions:
- [Terraform Issues](https://github.com/hashicorp/terraform/issues)
- [Azure Provider Issues](https://github.com/hashicorp/terraform-provider-azurerm/issues)
- [Azure Documentation](https://docs.microsoft.com/azure/)
