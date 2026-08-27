output "bucket_id" {
  description = "Name/ID of the state bucket."
  value       = aws_s3_bucket.state.id
}

output "bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting state."
  value       = aws_kms_key.state.arn
}
