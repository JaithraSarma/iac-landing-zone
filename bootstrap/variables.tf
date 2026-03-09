###############################################################################
# Bootstrap Variables
###############################################################################

variable "resource_group_name" {
  description = "Resource group for the Terraform state storage"
  type        = string
  default     = "rg-terraform-state"
}

variable "location" {
  description = "Azure region for the state storage"
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, 3-24 lowercase alphanumeric)"
  type        = string
  default     = "stterraformstate001"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default = {
    Environment = "management"
    ManagedBy   = "terraform"
    Purpose     = "terraform-state"
  }
}
