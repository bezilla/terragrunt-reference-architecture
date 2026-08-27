# State backend bootstrap.
#
# The one thing a fresh clone must apply before anything else, kept deliberately small: a
# customer-managed KMS key, and an S3 bucket with versioning, encryption, and public access fully
# blocked. There is no DynamoDB lock table — locking uses S3 native conditional writes
# (use_lockfile = true in the Terragrunt remote_state config), which removes a whole resource and
# its IAM surface (see docs/adr/0005).
#
# Chicken-and-egg: this module's own state is created locally, then migrated into the bucket it
# creates. The README documents that one-time bootstrap. The KMS key does not depend on the
# bucket, so both are created in the same apply.

resource "aws_kms_key" "state" {
  description             = "Encrypts OpenTofu/Terraform state in ${var.bucket_name}."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.bucket_name}"
  target_key_id = aws_kms_key.state.key_id
}

# A state bucket is the root of the bootstrap chain; enabling S3 access logging would need a
# second, separately-managed log bucket (and logging on *that* bucket is circular). Access to
# state is audited via CloudTrail data events instead. Deliberate omission.
#trivy:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
  tags   = var.tags
}

# Object Ownership enforced so the bucket owner controls all objects; ACLs disabled.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # Expire old state versions so the bucket does not grow without bound, and clean up
  # incomplete multipart uploads.
  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}
