# Main Terraform configuration for brettappscode Azure infrastructure
# This template creates all required Azure resources for the application

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
    }
  }
}

# ============================================
# Data sources
# ============================================
data "azurerm_client_config" "current" {}

# ============================================
# Resource Group
# ============================================
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ============================================
# Container Registry (ACR)
# ============================================
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# ============================================
# Log Analytics Workspace
# ============================================
resource "azurerm_log_analytics_workspace" "logs" {
  name                = var.log_analytics_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ============================================
# Application Insights
# ============================================
resource "azurerm_application_insights" "appinsights" {
  name                = var.app_insights_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.logs.id
  tags                = var.tags
}

# ============================================
# Storage Account
# ============================================
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  
  tags = var.tags
}

# ============================================
# Key Vault
# ============================================
resource "azurerm_key_vault" "keyvault" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = var.tags
}

# Key Vault Access Policy for current user/service principal
resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Purge"
  ]
}

# ============================================
# SQL Server
# ============================================
resource "azurerm_mssql_server" "sqlserver" {
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
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# SQL Database
resource "azurerm_mssql_database" "database" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.sqlserver.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = 2
  sku_name       = var.sql_database_sku
  zone_redundant = false

  tags = var.tags
}

# ============================================
# App Service Plan
# ============================================
resource "azurerm_service_plan" "appplan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku

  tags = var.tags
}

# ============================================
# App Service (Web App for Containers)
# ============================================
resource "azurerm_linux_web_app" "webapp" {
  name                = var.app_service_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.appplan.id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    ftps_state = "Disabled"
    minimum_tls_version = "1.2"
    
    application_stack {
      docker_image_name   = "nginx:latest"  # Placeholder, updated by pipeline
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = azurerm_container_registry.acr.admin_username
      docker_registry_password = azurerm_container_registry.acr.admin_password
    }
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "WEBSITES_PORT"                       = "3000"
    "PORT"                                = "3000"
    "NODE_ENV"                            = "production"
    "KEY_VAULT_NAME"                      = azurerm_key_vault.keyvault.name
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appinsights.connection_string
  }

  tags = var.tags
}

# Key Vault Access Policy for App Service Managed Identity
resource "azurerm_key_vault_access_policy" "webapp" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = azurerm_linux_web_app.webapp.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.webapp.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  depends_on = [azurerm_linux_web_app.webapp]
}

# Store Application Insights Connection String in Key Vault
resource "azurerm_key_vault_secret" "appinsights_connection_string" {
  name         = "APPINSIGHTS-CONNECTION-STRING"
  value        = azurerm_application_insights.appinsights.connection_string
  key_vault_id = azurerm_key_vault.keyvault.id

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

# ============================================
# Optional: Azure Kubernetes Service (AKS)
# Uncomment to deploy AKS
# ============================================
# resource "azurerm_kubernetes_cluster" "aks" {
#   name                = var.aks_cluster_name
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   dns_prefix          = "${var.aks_cluster_name}-dns"

#   default_node_pool {
#     name       = "default"
#     node_count = var.aks_node_count
#     vm_size    = var.aks_node_vm_size
#   }

#   identity {
#     type = "SystemAssigned"
#   }

#   network_profile {
#     network_plugin    = "azure"
#     load_balancer_sku = "standard"
#   }

#   tags = var.tags
# }

# # Grant AKS pull access to ACR
# resource "azurerm_role_assignment" "aks_acr_pull" {
#   scope                = azurerm_container_registry.acr.id
#   role_definition_name = "AcrPull"
#   principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
# }
