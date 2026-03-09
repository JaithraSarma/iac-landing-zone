###############################################################################
# Staging Environment - Main Configuration
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
    key                  = "staging/terraform.tfstate"
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
  address_space                 = ["10.20.0.0/16"]
  dns_servers                   = []
  enable_gateway_subnet         = true
  gateway_subnet_prefix         = "10.20.1.0/24"
  enable_firewall_subnet        = true
  firewall_subnet_prefix        = "10.20.2.0/24"
  enable_bastion_subnet         = true
  bastion_subnet_prefix         = "10.20.3.0/24"
  shared_services_subnet_prefix = "10.20.4.0/24"

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
  address_space           = ["10.21.0.0/16"]
  hub_vnet_id             = module.azure_hub.vnet_id
  hub_vnet_name           = module.azure_hub.vnet_name
  hub_resource_group_name = module.azure_hub.resource_group_name

  subnets = {
    "snet-app" = {
      address_prefix = "10.21.1.0/24"
      delegation     = null
    }
    "snet-data" = {
      address_prefix = "10.21.2.0/24"
      delegation     = null
    }
    "snet-appgw" = {
      address_prefix = "10.21.3.0/24"
      delegation     = null
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Azure NSGs
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
      source_address_prefix      = "10.20.0.0/8"
      destination_address_prefix = "*"
    },
    {
      name                       = "Allow-AppGW-Inbound"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80-443"
      source_address_prefix      = "10.21.3.0/24"
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
      source_address_prefix      = "10.21.1.0/24"
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
# Azure Application Gateway (staging gets an AppGW)
# ---------------------------------------------------------------------------
module "azure_app_gateway" {
  source = "../../modules/azure/app-gateway"

  app_gateway_name    = "appgw-${var.environment}"
  location            = var.azure_location
  resource_group_name = module.azure_spoke_workload.resource_group_name
  subnet_id           = module.azure_spoke_workload.subnet_ids["snet-appgw"]

  sku_name     = "Standard_v2"
  sku_tier     = "Standard_v2"
  sku_capacity = 1

  backend_address_pools = [
    {
      name         = "default-pool"
      ip_addresses = []
      fqdns        = []
    }
  ]

  backend_http_settings = [
    {
      name                  = "default-http-settings"
      cookie_based_affinity = "Disabled"
      port                  = 80
      protocol              = "Http"
      request_timeout       = 30
    }
  ]

  http_listeners = [
    { name = "default-listener" }
  ]

  request_routing_rules = [
    {
      name                       = "default-rule"
      priority                   = 100
      rule_type                  = "Basic"
      http_listener_name         = "default-listener"
      backend_address_pool_name  = "default-pool"
      backend_http_settings_name = "default-http-settings"
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
  vpc_cidr           = "10.30.0.0/16"
  az_count           = 2
  enable_nat_gateway = true
  enable_flow_logs   = false

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# AWS S3 Bucket
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
          days          = 60
          storage_class = "STANDARD_IA"
        }
      ]
      expiration_days = 180
    }
  ]

  tags = local.common_tags
}
