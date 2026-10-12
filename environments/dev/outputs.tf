output "vpc_id" {
  description = "ID of the environment VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "app_security_group_id" {
  description = "Security group ID for the application tier"
  value       = module.app_security_group.security_group_id
}

output "artifacts_bucket_id" {
  description = "Name of the artifacts bucket"
  value       = module.artifacts_bucket.bucket_id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts bucket"
  value       = module.artifacts_bucket.bucket_arn
}
