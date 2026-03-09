###############################################################################
# Dev Environment - Main Configuration
# Provisions Azure hub-spoke networking and AWS VPC for the dev environment.
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
    key                  = "dev/terraform.tfstate"
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
  address_space                 = ["10.0.0.0/16"]
  dns_servers                   = []
  enable_gateway_subnet         = true
  gateway_subnet_prefix         = "10.0.1.0/24"
  enable_firewall_subnet        = true
  firewall_subnet_prefix        = "10.0.2.0/24"
  enable_bastion_subnet         = true
  bastion_subnet_prefix         = "10.0.3.0/24"
  shared_services_subnet_prefix = "10.0.4.0/24"

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
  address_space           = ["10.1.0.0/16"]
  hub_vnet_id             = module.azure_hub.vnet_id
  hub_vnet_name           = module.azure_hub.vnet_name
  hub_resource_group_name = module.azure_hub.resource_group_name

  subnets = {
    "snet-app" = {
      address_prefix = "10.1.1.0/24"
      delegation     = null
    }
    "snet-data" = {
      address_prefix = "10.1.2.0/24"
      delegation     = null
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Azure NSG - Workload App Subnet
# ---------------------------------------------------------------------------
module "azure_nsg_app" {
  source = "../../modules/azure/nsg"

  nsg_name            = "nsg-app-${var.environment}"
  location            = var.azure_location
  resource_group_name = module.azure_spoke_workload.resource_group_name

  subnet_ids = [module.azure_spoke_workload.subnet_ids["snet-app"]]

  security_rules = [
    {
      name                       = "Allow-HTTPS-Inbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "*"
    },
    {
      name                       = "Allow-HTTP-Inbound"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "10.0.0.0/8"
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
# Azure NSG - Workload Data Subnet
# ---------------------------------------------------------------------------
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
      source_address_prefix      = "10.1.1.0/24"
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
# AWS VPC
# ---------------------------------------------------------------------------
module "aws_vpc" {
  source = "../../modules/aws/vpc"

  vpc_name           = "vpc-${var.environment}"
  vpc_cidr           = "10.10.0.0/16"
  az_count           = 2
  enable_nat_gateway = var.environment != "dev" # Save costs in dev
  enable_flow_logs   = false

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# AWS S3 Bucket (workload artifacts)
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
          days          = 90
          storage_class = "STANDARD_IA"
        }
      ]
      expiration_days = 365
    }
  ]

  tags = local.common_tags
}
