# Terraform outputs

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "Login server URL for Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  description = "Name of Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_admin_username" {
  description = "Admin username for ACR"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for ACR"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.webapp.name
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.webapp.default_hostname
}

output "app_service_url" {
  description = "URL of the App Service"
  value       = "https://${azurerm_linux_web_app.webapp.default_hostname}"
}

output "app_service_principal_id" {
  description = "Principal ID of the App Service managed identity"
  value       = azurerm_linux_web_app.webapp.identity[0].principal_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.keyvault.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.keyvault.vault_uri
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.sqlserver.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.database.name
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.storage.name
}

output "storage_account_primary_access_key" {
  description = "Primary access key for Storage Account"
  value       = azurerm_storage_account.storage.primary_access_key
  sensitive   = true
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.appinsights.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.appinsights.connection_string
  sensitive   = true
}

# Optional: AKS outputs (uncomment if using AKS)
# output "aks_cluster_name" {
#   description = "Name of the AKS cluster"
#   value       = azurerm_kubernetes_cluster.aks.name
# }

# output "aks_cluster_fqdn" {
#   description = "FQDN of the AKS cluster"
#   value       = azurerm_kubernetes_cluster.aks.fqdn
# }

# output "aks_kube_config" {
#   description = "Kubernetes configuration for AKS"
#   value       = azurerm_kubernetes_cluster.aks.kube_config_raw
#   sensitive   = true
# }
