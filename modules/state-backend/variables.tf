variable "bucket_name" {
  description = "Globally-unique name for the S3 bucket that stores OpenTofu/Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]{3,63}$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name (3-63 chars, lowercase letters, numbers, dots, hyphens)."
  }
}

variable "noncurrent_version_retention_days" {
  description = "How many days to retain noncurrent state versions before expiring them."
  type        = number
  default     = 90
  nullable    = false

  validation {
    condition     = var.noncurrent_version_retention_days >= 1
    error_message = "noncurrent_version_retention_days must be at least 1."
  }
}

variable "tags" {
  description = "Additional tags to apply, merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
