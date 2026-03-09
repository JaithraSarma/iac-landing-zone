###############################################################################
# Bootstrap Outputs
###############################################################################

output "resource_group_name" {
  description = "Resource group containing the state storage"
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Name of the storage account for remote state"
  value       = azurerm_storage_account.tfstate.name
}

output "container_name" {
  description = "Name of the blob container for state files"
  value       = azurerm_storage_container.tfstate.name
}

output "primary_access_key" {
  description = "Primary access key (sensitive)"
  value       = azurerm_storage_account.tfstate.primary_access_key
  sensitive   = true
}
