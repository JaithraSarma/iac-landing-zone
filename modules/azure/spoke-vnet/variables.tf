###############################################################################
# Azure Spoke VNet Module - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group for the spoke VNet"
  type        = string
}

variable "location" {
  description = "Azure region for the spoke VNet"
  type        = string
}

variable "vnet_name" {
  description = "Name of the spoke virtual network"
  type        = string
}

variable "address_space" {
  description = "Address space for the spoke VNet"
  type        = list(string)
}

variable "dns_servers" {
  description = "Custom DNS servers. Empty list uses Azure-provided DNS."
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "Map of subnets to create in the spoke VNet"
  type = map(object({
    address_prefix = string
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
  }))
  default = {}
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub virtual network for peering"
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub virtual network"
  type        = string
}

variable "hub_resource_group_name" {
  description = "Resource group name of the hub virtual network"
  type        = string
}

variable "use_remote_gateways" {
  description = "Whether the spoke uses the hub's VPN gateway"
  type        = bool
  default     = false
}

variable "allow_gateway_transit" {
  description = "Whether the hub allows gateway transit to the spoke"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
