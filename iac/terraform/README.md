# Terraform Infrastructure for brettappscode

This directory contains Terraform configuration files to deploy the Azure infrastructure for the brettappscode application.

## Prerequisites

1. **Terraform**: Install Terraform >= 1.0
   ```bash
   # Using Homebrew (macOS)
   brew install terraform
   
   # Or download from https://www.terraform.io/downloads
   ```

2. **Azure CLI**: Install and authenticate
   ```bash
   # Install Azure CLI
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Login to Azure
   az login
   
   # Set subscription
   az account set --subscription "your-subscription-id"
   ```

## Configuration

Create a `terraform.tfvars` file with your configuration:

```hcl
resource_group_name  = "rg-brettappscode-prod"
location             = "eastus"
acr_name             = "acrbrettappscode"  # Must be globally unique
app_service_plan_name = "asp-brettappscode-prod"
app_service_name     = "app-brettappscode-prod"  # Must be globally unique
key_vault_name       = "kv-brettappscode"  # Must be globally unique
sql_server_name      = "sql-brettappscode"  # Must be globally unique
sql_admin_login      = "sqladmin"
sql_admin_password   = "YourSecurePassword123!"  # Change this!
sql_database_name    = "brettappsdb"
storage_account_name = "stbrettappscode"  # Must be globally unique, lowercase
app_insights_name    = "appi-brettappscode-prod"
log_analytics_name   = "law-brettappscode-prod"

# Optional: Override default SKUs
app_service_plan_sku = "B1"  # B1, B2, B3, S1, S2, S3, P1v2, P2v2, P3v2
sql_database_sku     = "Basic"  # Basic, S0, S1, etc.

# Optional: Custom tags
tags = {
  Environment = "Production"
  Application = "brettappscode"
  ManagedBy   = "Terraform"
  Owner       = "DevOps Team"
}
```

## Deployment Steps

### 1. Initialize Terraform

```bash
cd iac/terraform
terraform init
```

### 2. Validate Configuration

```bash
terraform validate
```

### 3. Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully before applying.

### 4. Apply Configuration

```bash
terraform apply tfplan
```

Or without saving a plan:

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. View Outputs

```bash
terraform output
```

To get sensitive outputs:

```bash
terraform output -json
```

## Using Terraform in Azure Pipeline

Add the following task to your pipeline:

```yaml
- task: TerraformInstaller@0
  displayName: 'Install Terraform'
  inputs:
    terraformVersion: '1.5.0'

- task: TerraformTaskV4@4
  displayName: 'Terraform Init'
  inputs:
    provider: 'azurerm'
    command: 'init'
    workingDirectory: '$(System.DefaultWorkingDirectory)/iac/terraform'
    backendServiceArm: '$(AZURE_SERVICE_CONNECTION)'
    backendAzureRmResourceGroupName: 'rg-terraform-state'
    backendAzureRmStorageAccountName: 'sttfstate'
    backendAzureRmContainerName: 'tfstate'
    backendAzureRmKey: 'brettappscode.tfstate'

- task: TerraformTaskV4@4
  displayName: 'Terraform Plan'
  inputs:
    provider: 'azurerm'
    command: 'plan'
    workingDirectory: '$(System.DefaultWorkingDirectory)/iac/terraform'
    environmentServiceNameAzureRM: '$(AZURE_SERVICE_CONNECTION)'
    commandOptions: '-var-file="production.tfvars"'

- task: TerraformTaskV4@4
  displayName: 'Terraform Apply'
  inputs:
    provider: 'azurerm'
    command: 'apply'
    workingDirectory: '$(System.DefaultWorkingDirectory)/iac/terraform'
    environmentServiceNameAzureRM: '$(AZURE_SERVICE_CONNECTION)'
    commandOptions: '-var-file="production.tfvars" -auto-approve'
```

## Destroy Infrastructure

**Warning**: This will delete all resources!

```bash
terraform destroy
```

## State Management

### Local State (Development)

By default, Terraform stores state locally in `terraform.tfstate`. For production, use remote state.

### Remote State (Production)

Configure Azure Storage backend in a `backend.tf` file:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate"
    container_name       = "tfstate"
    key                  = "brettappscode.tfstate"
  }
}
```

Create the backend storage:

```bash
# Create resource group
az group create --name rg-terraform-state --location eastus

# Create storage account
az storage account create \
  --resource-group rg-terraform-state \
  --name sttfstate \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstate
```

## Security Best Practices

1. **Never commit `terraform.tfvars`** - Add to `.gitignore`
2. **Use Azure Key Vault** for secrets in production
3. **Enable soft delete** on Key Vault (enabled by default in this config)
4. **Use service principal** with least privilege for automation
5. **Store state remotely** with encryption and locking
6. **Review plans carefully** before applying
7. **Use managed identities** instead of service principal passwords where possible

## Troubleshooting

### Resource Name Already Exists

Many Azure resources require globally unique names (ACR, Storage Account, Key Vault). If you get a naming conflict:

1. Change the resource name in `terraform.tfvars`
2. Run `terraform plan` again

### Authentication Issues

```bash
# Clear cached credentials
az account clear

# Login again
az login

# Verify subscription
az account show
```

### State Lock Issues

If Terraform state is locked:

```bash
terraform force-unlock <lock-id>
```

## Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Naming Conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
