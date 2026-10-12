variable "aws_region" {
  description = "AWS region where the state bucket and lock table live"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Environment this state backend serves"
  type        = string
  default     = "shared"
}

variable "owner" {
  description = "Team or individual accountable for these resources"
  type        = string
  default     = "platform-team"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table used for Terraform state locking"
  type        = string
  default     = "terraform-state-locks"
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent state object versions before expiring them"
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Allow the bucket to be destroyed even when it still holds state objects"
  type        = bool
  default     = false
}

variable "enable_access_logging" {
  description = "Write state bucket access logs to a dedicated logging bucket"
  type        = bool
  default     = true
}

variable "access_log_expiration_days" {
  description = "Days before access log objects expire"
  type        = number
  default     = 365
}

variable "flow_log_retention_days" {
  description = "Retention for the state bucket log group"
  type        = number
  default     = 365
}
