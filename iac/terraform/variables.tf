# Variables for Terraform Azure Infrastructure

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "app_service_plan_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "B1"
  validation {
    condition     = contains(["B1", "B2", "B3", "S1", "S2", "S3", "P1v2", "P2v2", "P3v2"], var.app_service_plan_sku)
    error_message = "App Service Plan SKU must be one of: B1, B2, B3, S1, S2, S3, P1v2, P2v2, P3v2"
  }
}

variable "app_service_name" {
  description = "Name of the App Service (Web App)"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "sql_server_name" {
  description = "Name of the SQL Server"
  type        = string
}

variable "sql_admin_login" {
  description = "SQL Server administrator login"
  type        = string
  default     = "sqladmin"
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "sql_database_name" {
  description = "Name of the SQL Database"
  type        = string
}

variable "sql_database_sku" {
  description = "SKU for SQL Database"
  type        = string
  default     = "Basic"
}

variable "storage_account_name" {
  description = "Name of the Storage Account"
  type        = string
}

variable "app_insights_name" {
  description = "Name of Application Insights"
  type        = string
}

variable "log_analytics_name" {
  description = "Name of Log Analytics Workspace"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Application = "brettappscode"
    ManagedBy   = "Terraform"
  }
}

# Optional: AKS variables (uncomment if using AKS)
# variable "aks_cluster_name" {
#   description = "Name of the AKS cluster"
#   type        = string
# }

# variable "aks_node_count" {
#   description = "Number of nodes in the AKS cluster"
#   type        = number
#   default     = 2
# }

# variable "aks_node_vm_size" {
#   description = "VM size for AKS nodes"
#   type        = string
#   default     = "Standard_B2s"
# }
