mock_provider "aws" {}

variables {
  bucket_name = "tfstate-123456789012-us-west-2"
}

run "hardened_bucket" {
  command = plan
  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket versioning must be enabled."
  }
  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "State bucket must use SSE-KMS."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.state.block_public_acls && aws_s3_bucket_public_access_block.state.restrict_public_buckets
    error_message = "Public access must be fully blocked."
  }
  assert {
    condition     = aws_kms_key.state.enable_key_rotation == true
    error_message = "State KMS key must have rotation enabled."
  }
}
