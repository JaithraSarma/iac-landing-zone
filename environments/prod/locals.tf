locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "iac-landing-zone"
  }
}
