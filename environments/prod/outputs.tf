###############################################################################
# Production Environment - Outputs
###############################################################################

output "azure_hub_vnet_id" {
  value = module.azure_hub.vnet_id
}

output "azure_hub_resource_group" {
  value = module.azure_hub.resource_group_name
}

output "azure_spoke_workload_vnet_id" {
  value = module.azure_spoke_workload.vnet_id
}

output "azure_spoke_subnet_ids" {
  value = module.azure_spoke_workload.subnet_ids
}

output "azure_app_gateway_public_ip" {
  value = module.azure_app_gateway.public_ip_address
}

output "aws_vpc_id" {
  value = module.aws_vpc.vpc_id
}

output "aws_public_subnet_ids" {
  value = module.aws_vpc.public_subnet_ids
}

output "aws_private_subnet_ids" {
  value = module.aws_vpc.private_subnet_ids
}

output "aws_s3_artifacts_arn" {
  value = module.aws_s3_artifacts.bucket_arn
}

output "aws_s3_flowlogs_arn" {
  value = module.aws_s3_flow_logs.bucket_arn
}

output "aws_bastion_public_ip" {
  value = module.aws_bastion.public_ip
}
