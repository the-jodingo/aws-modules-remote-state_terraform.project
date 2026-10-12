variable "name" {
  description = "Name prefix applied to every VPC resource"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3."
  }
}

variable "availability_zones" {
  description = "Explicit AZ names to place subnets in; empty discovers the first az_count zones in the region. Pinning this keeps the zone set from shifting when AWS adds new zones."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "Customer managed KMS key used to encrypt the flow log group; omit to use the CloudWatch default"
  type        = string
  default     = null
}

variable "public_subnet_newbits" {
  description = "Extra subnet bits for public subnets (e.g. 8 turns /16 into /24)"
  type        = number
  default     = 8
}

variable "private_subnet_newbits" {
  description = "Extra subnet bits for private subnets"
  type        = number
  default     = 8
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway so private subnets can reach the internet"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ (cheaper, less resilient)"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention period for flow log groups"
  type        = number
  default     = 365

  validation {
    condition = contains([
      "1", "3", "5", "7", "14", "30", "60", "90", "120", "150", "180",
      "365", "400", "545", "731", "1096", "1827", "2192", "2557", "2922",
      "3288", "3653",
    ], tostring(var.flow_log_retention_days))
    error_message = "flow_log_retention_days must be a value CloudWatch Logs accepts."
  }
}

variable "tags" {
  description = "Tags merged onto every resource created by this module"
  type        = map(string)
  default     = {}
}
