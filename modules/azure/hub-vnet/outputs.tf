###############################################################################
# Azure Hub VNet Module - Outputs
###############################################################################

output "resource_group_name" {
  description = "Name of the hub resource group"
  value       = azurerm_resource_group.hub.name
}

output "resource_group_id" {
  description = "ID of the hub resource group"
  value       = azurerm_resource_group.hub.id
}

output "vnet_name" {
  description = "Name of the hub virtual network"
  value       = azurerm_virtual_network.hub.name
}

output "vnet_id" {
  description = "ID of the hub virtual network"
  value       = azurerm_virtual_network.hub.id
}

output "vnet_address_space" {
  description = "Address space of the hub virtual network"
  value       = azurerm_virtual_network.hub.address_space
}

output "gateway_subnet_id" {
  description = "ID of the GatewaySubnet (if created)"
  value       = var.enable_gateway_subnet ? azurerm_subnet.gateway[0].id : null
}

output "firewall_subnet_id" {
  description = "ID of the AzureFirewallSubnet (if created)"
  value       = var.enable_firewall_subnet ? azurerm_subnet.firewall[0].id : null
}

output "bastion_subnet_id" {
  description = "ID of the AzureBastionSubnet (if created)"
  value       = var.enable_bastion_subnet ? azurerm_subnet.bastion[0].id : null
}

output "shared_services_subnet_id" {
  description = "ID of the shared services subnet"
  value       = azurerm_subnet.shared_services.id
}
