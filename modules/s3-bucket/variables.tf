variable "bucket_name" {
  description = "Globally unique bucket name"
  type        = string
}

variable "versioning_enabled" {
  description = "Keep every version of every object"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Customer managed KMS key for default encryption; omit to use SSE-S3"
  type        = string
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent object versions expire"
  type        = number
  default     = 90
}

variable "lifecycle_glacier_transition_days" {
  description = "Days before current versions transition to Glacier; 0 disables the rule"
  type        = number
  default     = 0
}

variable "logging_bucket" {
  description = "Optional bucket to receive access logs"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags merged onto every resource created by this module"
  type        = map(string)
  default     = {}
}
