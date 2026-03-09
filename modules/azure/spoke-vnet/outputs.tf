###############################################################################
# Azure Spoke VNet Module - Outputs
###############################################################################

output "resource_group_name" {
  description = "Name of the spoke resource group"
  value       = azurerm_resource_group.spoke.name
}

output "resource_group_id" {
  description = "ID of the spoke resource group"
  value       = azurerm_resource_group.spoke.id
}

output "vnet_name" {
  description = "Name of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.name
}

output "vnet_id" {
  description = "ID of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.id
}

output "vnet_address_space" {
  description = "Address space of the spoke virtual network"
  value       = azurerm_virtual_network.spoke.address_space
}

output "subnet_ids" {
  description = "Map of subnet name to subnet ID"
  value       = { for k, v in azurerm_subnet.workload : k => v.id }
}

output "peering_spoke_to_hub_id" {
  description = "ID of the spoke-to-hub peering"
  value       = azurerm_virtual_network_peering.spoke_to_hub.id
}

output "peering_hub_to_spoke_id" {
  description = "ID of the hub-to-spoke peering"
  value       = azurerm_virtual_network_peering.hub_to_spoke.id
}
