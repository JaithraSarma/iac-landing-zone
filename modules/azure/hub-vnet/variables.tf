###############################################################################
# Azure Hub VNet Module - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group for the hub VNet"
  type        = string
}

variable "location" {
  description = "Azure region for the hub VNet"
  type        = string
}

variable "vnet_name" {
  description = "Name of the hub virtual network"
  type        = string
}

variable "address_space" {
  description = "Address space for the hub VNet (e.g., [\"10.0.0.0/16\"])"
  type        = list(string)
}

variable "dns_servers" {
  description = "Custom DNS servers for the hub VNet. Empty list uses Azure-provided DNS."
  type        = list(string)
  default     = []
}

variable "enable_gateway_subnet" {
  description = "Whether to create a GatewaySubnet for VPN/ExpressRoute"
  type        = bool
  default     = true
}

variable "gateway_subnet_prefix" {
  description = "Address prefix for the GatewaySubnet"
  type        = string
  default     = ""
}

variable "enable_firewall_subnet" {
  description = "Whether to create an AzureFirewallSubnet"
  type        = bool
  default     = true
}

variable "firewall_subnet_prefix" {
  description = "Address prefix for the AzureFirewallSubnet"
  type        = string
  default     = ""
}

variable "enable_bastion_subnet" {
  description = "Whether to create an AzureBastionSubnet"
  type        = bool
  default     = true
}

variable "bastion_subnet_prefix" {
  description = "Address prefix for the AzureBastionSubnet"
  type        = string
  default     = ""
}

variable "shared_services_subnet_prefix" {
  description = "Address prefix for the shared services subnet"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
