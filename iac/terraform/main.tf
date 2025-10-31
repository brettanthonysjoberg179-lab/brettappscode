#=========================================================================
# Azure Infrastructure as Code - Terraform Configuration
#
# This Terraform configuration creates:
# - Azure Container Registry (ACR)
# - App Service Plan (Linux)
# - App Service (Web App for Containers)
# - Azure Key Vault
# - Azure SQL Server and Database
# - Storage Account
# - Application Insights
# - Log Analytics Workspace
#
# Usage:
# 1. terraform init
# 2. terraform plan -var-file="terraform.tfvars"
# 3. terraform apply -var-file="terraform.tfvars"
#=========================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  # Optional: Configure backend for remote state
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstatestorage"
  #   container_name       = "tfstate"
  #   key                  = "brettappscode.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

#=========================================================================
# Data Sources
#=========================================================================
data "azurerm_client_config" "current" {}

#=========================================================================
# Resource Group
#=========================================================================
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = var.tags
}

#=========================================================================
# Azure Container Registry
#=========================================================================
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  
  tags = var.tags
}

#=========================================================================
# Log Analytics Workspace
#=========================================================================
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.app_service_name}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = var.tags
}

#=========================================================================
# Application Insights
#=========================================================================
resource "azurerm_application_insights" "appinsights" {
  name                = var.app_insights_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.logs.id
  application_type    = "web"
  
  tags = var.tags
}

#=========================================================================
# App Service Plan (Linux)
#=========================================================================
resource "azurerm_service_plan" "plan" {
  name                = "${var.app_service_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  
  tags = var.tags
}

#=========================================================================
# App Service (Web App for Containers)
#=========================================================================
resource "azurerm_linux_web_app" "app" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true
  
  identity {
    type = "SystemAssigned"
  }
  
  site_config {
    always_on         = true
    ftps_state        = "Disabled"
    minimum_tls_version = "1.2"
    
    application_stack {
      docker_image     = "nginx"
      docker_image_tag = "latest"
    }
  }
  
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "DOCKER_REGISTRY_SERVER_URL"          = "https://${azurerm_container_registry.acr.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME"     = azurerm_container_registry.acr.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD"     = azurerm_container_registry.acr.admin_password
    "APPINSIGHTS_INSTRUMENTATIONKEY"      = azurerm_application_insights.appinsights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appinsights.connection_string
    "KEY_VAULT_URI"                       = azurerm_key_vault.kv.vault_uri
    "PORT"                                = "3000"
    "NODE_ENV"                            = "production"
  }
  
  tags = var.tags
}

#=========================================================================
# Azure Key Vault
#=========================================================================
resource "azurerm_key_vault" "kv" {
  name                       = var.key_vault_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = false
  
  # Access policy for App Service Managed Identity
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_web_app.app.identity[0].principal_id
    
    secret_permissions = [
      "Get",
      "List"
    ]
  }
  
  # Access policy for current user/service principal (for deployment)
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
  
  tags = var.tags
}

#=========================================================================
# Azure SQL Server
#=========================================================================
resource "azurerm_mssql_server" "sql" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  
  tags = var.tags
}

# SQL Server Firewall Rule - Allow Azure Services
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

#=========================================================================
# Azure SQL Database
#=========================================================================
resource "azurerm_mssql_database" "db" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.sql.id
  collation = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb = 2
  sku_name  = "Basic"
  
  tags = var.tags
}

#=========================================================================
# Storage Account
#=========================================================================
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  
  blob_properties {
    versioning_enabled = true
  }
  
  tags = var.tags
}

#=========================================================================
# Store SQL Connection String in Key Vault
#=========================================================================
resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "SqlConnectionString"
  value        = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};User ID=${var.sql_admin_login};Password=${var.sql_admin_password};Encrypt=true;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id
  
  depends_on = [
    azurerm_key_vault.kv
  ]
}
