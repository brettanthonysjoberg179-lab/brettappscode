# Azure Infrastructure as Code - Terraform Configuration
# Deploys: Resource Group, ACR, App Service Plan, App Service, Key Vault, Application Insights

# Configure the Azure Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Variables
variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "acr_name" {
  description = "The name of the Azure Container Registry"
  type        = string
}

variable "app_service_name" {
  description = "The name of the App Service"
  type        = string
}

variable "key_vault_name" {
  description = "The name of the Key Vault"
  type        = string
}

variable "sql_server_name" {
  description = "The name of the SQL Server"
  type        = string
}

variable "sql_database_name" {
  description = "The name of the SQL Database"
  type        = string
}

variable "sql_admin_login" {
  description = "The SQL Server administrator login"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "The SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "app_insights_name" {
  description = "The name of Application Insights"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Application = "brettappscode"
  }
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# ===========================
# Resource Group
# ===========================
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ===========================
# Azure Container Registry (ACR)
# ===========================
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# ===========================
# Application Insights
# ===========================
resource "azurerm_application_insights" "app_insights" {
  name                = var.app_insights_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
  tags                = var.tags
}

# ===========================
# App Service Plan (Linux)
# ===========================
resource "azurerm_service_plan" "app_service_plan" {
  name                = "${var.app_service_name}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = var.tags
}

# ===========================
# App Service (Web App for Containers)
# ===========================
resource "azurerm_linux_web_app" "app_service" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.app_service_plan.id
  https_only          = true
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    
    application_stack {
      docker_image_name   = "mcr.microsoft.com/appsvc/staticsite:latest"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
  }

  app_settings = {
    WEBSITES_PORT                         = "3000"
    DOCKER_REGISTRY_SERVER_URL           = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME      = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD      = azurerm_container_registry.acr.admin_password
    APPINSIGHTS_INSTRUMENTATIONKEY       = azurerm_application_insights.app_insights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.app_insights.connection_string
    KEY_VAULT_URI                        = azurerm_key_vault.key_vault.vault_uri
    NODE_ENV                             = "production"
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Server=tcp:${azurerm_mssql_server.sql_server.fully_qualified_domain_name},1433;Initial Catalog=${var.sql_database_name};Persist Security Info=False;User ID=${var.sql_admin_login};Password=${var.sql_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}

# ===========================
# Key Vault
# ===========================
resource "azurerm_key_vault" "key_vault" {
  name                        = var.key_vault_name
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 90
  purge_protection_enabled    = false
  enable_rbac_authorization   = false
  tags                        = var.tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  # Access policy for App Service Managed Identity
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_web_app.app_service.identity[0].principal_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }
}

# Store SQL admin password in Key Vault
resource "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.key_vault.id
  
  depends_on = [
    azurerm_key_vault.key_vault
  ]
}

# ===========================
# Azure SQL Server
# ===========================
resource "azurerm_mssql_server" "sql_server" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  tags                         = var.tags
}

# SQL Server Firewall Rule - Allow Azure Services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Azure SQL Database
resource "azurerm_mssql_database" "sql_database" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.sql_server.id
  collation = "SQL_Latin1_General_CP1_CI_AS"
  sku_name  = "Basic"
  max_size_gb = 2
  tags      = var.tags
}

# ===========================
# Storage Account
# ===========================
resource "azurerm_storage_account" "storage" {
  name                     = "stor${substr(sha256(azurerm_resource_group.rg.id), 0, 18)}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  blob_properties {
    versioning_enabled = true
  }
}

# Storage Account Blob Container
resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# ===========================
# Outputs
# ===========================
output "acr_login_server" {
  description = "The login server URL for the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "app_service_url" {
  description = "The URL of the App Service"
  value       = "https://${azurerm_linux_web_app.app_service.default_hostname}"
}

output "app_service_principal_id" {
  description = "The Principal ID of the App Service Managed Identity"
  value       = azurerm_linux_web_app.app_service.identity[0].principal_id
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.key_vault.vault_uri
}

output "sql_server_fqdn" {
  description = "The fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "storage_account_name" {
  description = "The name of the Storage Account"
  value       = azurerm_storage_account.storage.name
}

output "app_insights_instrumentation_key" {
  description = "The Instrumentation Key for Application Insights"
  value       = azurerm_application_insights.app_insights.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "The Connection String for Application Insights"
  value       = azurerm_application_insights.app_insights.connection_string
  sensitive   = true
}

# ===========================
# Terraform Initialization Notes
# ===========================
# To initialize and apply this Terraform configuration:
#
# 1. Initialize Terraform:
#    terraform init
#
# 2. Create a terraform.tfvars file with your values:
#    resource_group_name = "my-resource-group"
#    location = "eastus"
#    acr_name = "myacr"
#    app_service_name = "myappservice"
#    key_vault_name = "mykeyvault"
#    sql_server_name = "mysqlserver"
#    sql_database_name = "mydb"
#    sql_admin_password = "YourSecurePassword123!"
#    app_insights_name = "myappinsights"
#
# 3. Plan the deployment:
#    terraform plan
#
# 4. Apply the configuration:
#    terraform apply
#
# 5. Destroy resources (when needed):
#    terraform destroy
