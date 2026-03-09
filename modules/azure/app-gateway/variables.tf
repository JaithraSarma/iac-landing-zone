###############################################################################
# Azure Application Gateway Module - Variables
###############################################################################

variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the Application Gateway"
  type        = string
}

variable "sku_name" {
  description = "SKU name (Standard_v2 or WAF_v2)"
  type        = string
  default     = "Standard_v2"
}

variable "sku_tier" {
  description = "SKU tier (Standard_v2 or WAF_v2)"
  type        = string
  default     = "Standard_v2"
}

variable "sku_capacity" {
  description = "Number of instances"
  type        = number
  default     = 2
}

variable "backend_address_pools" {
  description = "List of backend address pools"
  type = list(object({
    name         = string
    ip_addresses = optional(list(string), [])
    fqdns        = optional(list(string), [])
  }))
}

variable "backend_http_settings" {
  description = "List of backend HTTP settings"
  type = list(object({
    name                  = string
    cookie_based_affinity = string
    port                  = number
    protocol              = string
    request_timeout       = number
  }))
}

variable "http_listeners" {
  description = "List of HTTP listeners"
  type = list(object({
    name = string
  }))
}

variable "request_routing_rules" {
  description = "List of request routing rules"
  type = list(object({
    name                       = string
    priority                   = number
    rule_type                  = string
    http_listener_name         = string
    backend_address_pool_name  = string
    backend_http_settings_name = string
  }))
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
