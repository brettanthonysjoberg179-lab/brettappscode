#=========================================================================
# Terraform Outputs
#
# Outputs important resource information after deployment
#=========================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

#=========================================================================
# Container Registry Outputs
#=========================================================================
output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server for the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "Admin username for the Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

#=========================================================================
# App Service Outputs
#=========================================================================
output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.app.name
}

output "app_service_url" {
  description = "URL of the App Service"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "app_service_principal_id" {
  description = "Principal ID of the App Service managed identity"
  value       = azurerm_linux_web_app.app.identity[0].principal_id
}

#=========================================================================
# Key Vault Outputs
#=========================================================================
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

#=========================================================================
# SQL Server Outputs
#=========================================================================
output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = azurerm_mssql_server.sql.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.db.name
}

#=========================================================================
# Storage Account Outputs
#=========================================================================
output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.storage.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = azurerm_storage_account.storage.primary_blob_endpoint
}

#=========================================================================
# Application Insights Outputs
#=========================================================================
output "app_insights_name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.appinsights.name
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.appinsights.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.appinsights.connection_string
  sensitive   = true
}

#=========================================================================
# Log Analytics Outputs
#=========================================================================
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.logs.id
}
