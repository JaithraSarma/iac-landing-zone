###############################################################################
# Production Environment - Main Configuration
# Full-featured: App Gateway, NAT, flow logs, tighter NSGs.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate001"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Azure Hub VNet
# ---------------------------------------------------------------------------
module "azure_hub" {
  source = "../../modules/azure/hub-vnet"

  resource_group_name           = "rg-hub-${var.environment}"
  location                      = var.azure_location
  vnet_name                     = "vnet-hub-${var.environment}"
  address_space                 = ["10.40.0.0/16"]
  dns_servers                   = []
  enable_gateway_subnet         = true
  gateway_subnet_prefix         = "10.40.1.0/24"
  enable_firewall_subnet        = true
  firewall_subnet_prefix        = "10.40.2.0/24"
  enable_bastion_subnet         = true
  bastion_subnet_prefix         = "10.40.3.0/24"
  shared_services_subnet_prefix = "10.40.4.0/24"

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Azure Spoke VNet - Workload
# ---------------------------------------------------------------------------
module "azure_spoke_workload" {
  source = "../../modules/azure/spoke-vnet"

  resource_group_name     = "rg-spoke-workload-${var.environment}"
  location                = var.azure_location
  vnet_name               = "vnet-spoke-workload-${var.environment}"
  address_space           = ["10.41.0.0/16"]
  hub_vnet_id             = module.azure_hub.vnet_id
  hub_vnet_name           = module.azure_hub.vnet_name
  hub_resource_group_name = module.azure_hub.resource_group_name

  subnets = {
    "snet-app" = {
      address_prefix = "10.41.1.0/24"
      delegation     = null
    }
    "snet-data" = {
      address_prefix = "10.41.2.0/24"
      delegation     = null
    }
    "snet-appgw" = {
      address_prefix = "10.41.3.0/24"
      delegation     = null
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Azure NSGs (production: tighter rules)
# ---------------------------------------------------------------------------
module "azure_nsg_app" {
  source = "../../modules/azure/nsg"

  nsg_name            = "nsg-app-${var.environment}"
  location            = var.azure_location
  resource_group_name = module.azure_spoke_workload.resource_group_name

  subnet_ids = [module.azure_spoke_workload.subnet_ids["snet-app"]]

  security_rules = [
    {
      name                       = "Allow-HTTPS-From-AppGW"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.41.3.0/24"
      destination_address_prefix = "*"
    },
    {
      name                       = "Allow-Health-Probes"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    },
    {
      name                       = "Deny-All-Inbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]

  tags = local.common_tags
}

module "azure_nsg_data" {
  source = "../../modules/azure/nsg"

  nsg_name            = "nsg-data-${var.environment}"
  location            = var.azure_location
  resource_group_name = module.azure_spoke_workload.resource_group_name

  subnet_ids = [module.azure_spoke_workload.subnet_ids["snet-data"]]

  security_rules = [
    {
      name                       = "Allow-SQL-From-App"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1433"
      source_address_prefix      = "10.41.1.0/24"
      destination_address_prefix = "*"
    },
    {
      name                       = "Deny-All-Inbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Azure Application Gateway (production: WAF tier)
# ---------------------------------------------------------------------------
module "azure_app_gateway" {
  source = "../../modules/azure/app-gateway"

  app_gateway_name    = "appgw-${var.environment}"
  location            = var.azure_location
  resource_group_name = module.azure_spoke_workload.resource_group_name
  subnet_id           = module.azure_spoke_workload.subnet_ids["snet-appgw"]

  sku_name     = "WAF_v2"
  sku_tier     = "WAF_v2"
  sku_capacity = 2

  backend_address_pools = [
    {
      name         = "prod-pool"
      ip_addresses = []
      fqdns        = []
    }
  ]

  backend_http_settings = [
    {
      name                  = "prod-http-settings"
      cookie_based_affinity = "Disabled"
      port                  = 443
      protocol              = "Https"
      request_timeout       = 30
    }
  ]

  http_listeners = [
    { name = "prod-listener" }
  ]

  request_routing_rules = [
    {
      name                       = "prod-rule"
      priority                   = 100
      rule_type                  = "Basic"
      http_listener_name         = "prod-listener"
      backend_address_pool_name  = "prod-pool"
      backend_http_settings_name = "prod-http-settings"
    }
  ]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# AWS VPC (production: NAT + flow logs)
# ---------------------------------------------------------------------------
module "aws_vpc" {
  source = "../../modules/aws/vpc"

  vpc_name             = "vpc-${var.environment}"
  vpc_cidr             = "10.50.0.0/16"
  az_count             = 3
  enable_nat_gateway   = true
  enable_flow_logs     = true
  flow_log_destination = module.aws_s3_flow_logs.bucket_arn

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# AWS S3 — VPC Flow Logs
# ---------------------------------------------------------------------------
module "aws_s3_flow_logs" {
  source = "../../modules/aws/s3"

  bucket_name       = "landing-zone-flowlogs-${var.environment}-${var.aws_account_id}"
  enable_versioning = false
  force_destroy     = false

  lifecycle_rules = [
    {
      id      = "expire-old-logs"
      enabled = true
      prefix  = ""
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      expiration_days = 365
    }
  ]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# AWS S3 — Workload Artifacts
# ---------------------------------------------------------------------------
module "aws_s3_artifacts" {
  source = "../../modules/aws/s3"

  bucket_name       = "landing-zone-artifacts-${var.environment}-${var.aws_account_id}"
  enable_versioning = true

  lifecycle_rules = [
    {
      id      = "archive-old-objects"
      enabled = true
      prefix  = ""
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      expiration_days = 365
    }
  ]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# AWS EC2 — Bastion Host in public subnet
# ---------------------------------------------------------------------------
module "aws_bastion" {
  source = "../../modules/aws/ec2"

  instance_name = "bastion-${var.environment}"
  instance_type = "t3.micro"
  vpc_id        = module.aws_vpc.vpc_id
  subnet_id     = module.aws_vpc.public_subnet_ids[0]

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.bastion_allowed_cidrs
      description = "SSH from allowed CIDRs"
    }
  ]

  tags = local.common_tags
}
