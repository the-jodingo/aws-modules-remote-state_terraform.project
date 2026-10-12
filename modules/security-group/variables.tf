variable "name" {
  description = "Name of the security group"
  type        = string
}

variable "description" {
  description = "Description of the security group"
  type        = string
  default     = "Managed security group"
}

variable "vpc_id" {
  description = "VPC the security group belongs to"
  type        = string
}

variable "ingress_rules" {
  description = "Inbound rules; each rule is a map with from_port, to_port, protocol, cidr_blocks, and optional description"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string, "Managed rule")
  }))
  default = []
}

variable "egress_rules" {
  description = "Outbound rules; each rule is a map with from_port, to_port, protocol, cidr_blocks, and optional description"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string, "Managed rule")
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

variable "tags" {
  description = "Tags merged onto every resource created by this module"
  type        = map(string)
  default     = {}
}
