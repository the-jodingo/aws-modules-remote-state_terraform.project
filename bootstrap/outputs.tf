output "state_bucket_id" {
  description = "Name of the S3 bucket holding Terraform state"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket holding Terraform state"
  value       = aws_s3_bucket.state.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting state objects"
  value       = aws_kms_key.state.arn
}

output "lock_table_name" {
  description = "DynamoDB table used for state locking"
  value       = aws_dynamodb_table.locks.name
}

output "backend_config" {
  description = "Copy this block into the terraform backend configuration"
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    key            = "<environment>/terraform.tfstate"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.locks.name}"
    encrypt        = true
    kms_key_id     = "${aws_kms_key.state.arn}"
  EOT
}
