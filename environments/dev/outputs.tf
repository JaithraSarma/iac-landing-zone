###############################################################################
# Dev Environment - Outputs
###############################################################################

# --- Azure Outputs ---
output "azure_hub_vnet_id" {
  description = "Hub VNet ID"
  value       = module.azure_hub.vnet_id
}

output "azure_hub_resource_group" {
  description = "Hub resource group name"
  value       = module.azure_hub.resource_group_name
}

output "azure_spoke_workload_vnet_id" {
  description = "Spoke workload VNet ID"
  value       = module.azure_spoke_workload.vnet_id
}

output "azure_spoke_subnet_ids" {
  description = "Spoke workload subnet IDs"
  value       = module.azure_spoke_workload.subnet_ids
}

# --- AWS Outputs ---
output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = module.aws_vpc.vpc_id
}

output "aws_public_subnet_ids" {
  description = "AWS public subnet IDs"
  value       = module.aws_vpc.public_subnet_ids
}

output "aws_private_subnet_ids" {
  description = "AWS private subnet IDs"
  value       = module.aws_vpc.private_subnet_ids
}

output "aws_s3_bucket_arn" {
  description = "AWS artifacts S3 bucket ARN"
  value       = module.aws_s3_artifacts.bucket_arn
}
