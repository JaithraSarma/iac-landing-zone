###############################################################################
# AWS CodePipeline Module - Variables
###############################################################################

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
  default     = "iac-landing-zone"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "repository_id" {
  description = "Full repository ID (e.g., 'owner/repo-name')"
  type        = string
}

variable "branch_name" {
  description = "Branch to trigger the pipeline"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection to the source repository"
  type        = string
}

variable "terraform_version" {
  description = "Terraform version to install in CodeBuild"
  type        = string
  default     = "1.5.7"
}

variable "approval_email" {
  description = "Email address for manual approval notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
