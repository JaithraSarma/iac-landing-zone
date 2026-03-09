###############################################################################
# Staging Environment - Variables
###############################################################################

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}
