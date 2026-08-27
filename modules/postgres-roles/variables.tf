variable "databases" {
  description = <<-EOT
    Logical databases to create on a shared Aurora cluster, each with an owner role. Keyed by
    database name. This is the "one cluster, many application databases" pattern: cheaper than a
    cluster per service, with per-application credentials and isolation via roles.
  EOT
  type = map(object({
    owner_role = string
  }))
  nullable = false

  validation {
    condition     = length(var.databases) > 0
    error_message = "Provide at least one database."
  }
}

variable "secret_prefix" {
  description = "SSM Parameter Store path prefix under which generated role credentials are stored."
  type        = string
  default     = "/acme/databases"
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags (applied to SSM parameters)."
  type        = map(string)
  default     = {}
  nullable    = false
}
