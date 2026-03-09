###############################################################################
# Azure Hub VNet Module
# Creates the central hub virtual network with optional subnets for:
#   - Azure Firewall
#   - VPN Gateway
#   - Azure Bastion
#   - Shared Services
###############################################################################

resource "azurerm_resource_group" "hub" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = var.vnet_name
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags
}

# Gateway Subnet (reserved name for VPN/ExpressRoute gateways)
resource "azurerm_subnet" "gateway" {
  count                = var.enable_gateway_subnet ? 1 : 0
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

# Azure Firewall Subnet (reserved name)
resource "azurerm_subnet" "firewall" {
  count                = var.enable_firewall_subnet ? 1 : 0
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

# Azure Bastion Subnet (reserved name)
resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion_subnet ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

# Shared Services Subnet
resource "azurerm_subnet" "shared_services" {
  name                 = "${var.vnet_name}-shared-services"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.shared_services_subnet_prefix]
}
