variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Team or individual accountable for these resources"
  type        = string
  default     = "platform-team"
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "availability_zones" {
  description = "Explicit AZ names to pin subnet placement; empty discovers them"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway for private subnet egress"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs"
  type        = number
  default     = 365
}

variable "artifacts_bucket_name" {
  description = "Globally unique name for the artifacts bucket"
  type        = string
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent object versions expire"
  type        = number
  default     = 90
}

variable "lifecycle_glacier_transition_days" {
  description = "Days before objects transition to Glacier; 0 disables"
  type        = number
  default     = 0
}
