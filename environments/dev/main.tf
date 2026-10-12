terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Values are supplied at init time so the same configuration works in every account:
  #   terraform init -backend-config=backend/dev.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                    = "${var.project_name}-${var.environment}"
  vpc_cidr                = var.vpc_cidr
  az_count                = var.az_count
  availability_zones      = var.availability_zones
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = true
  enable_flow_logs        = true
  flow_log_retention_days = var.flow_log_retention_days

  tags = local.common_tags
}

module "app_security_group" {
  source = "../../modules/security-group"

  name        = "${var.project_name}-${var.environment}-app"
  description = "Application tier security group for ${var.project_name} ${var.environment}"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "HTTPS from inside the VPC"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "Application port from inside the VPC"
    },
  ]

  tags = local.common_tags
}

module "artifacts_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name                        = var.artifacts_bucket_name
  versioning_enabled                 = true
  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
  lifecycle_glacier_transition_days  = var.lifecycle_glacier_transition_days

  tags = local.common_tags
}
