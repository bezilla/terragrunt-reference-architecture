variable "namespace" {
  description = "Name of the Kubernetes namespace to create."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a valid RFC 1123 label (lowercase alphanumerics and hyphens)."
  }
}

variable "labels" {
  description = "Labels to apply to the namespace."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "owner_team" {
  description = "Owning team label, for cost/allocation and paging lookups."
  type        = string
  default     = "platform-team"
  nullable    = false
}

variable "editor_group_subjects" {
  description = <<-EOT
    RBAC subjects granted edit rights in the namespace. Each is a Kubernetes group name, typically
    mapped from an IAM role via EKS access entries. Defaults are illustrative.
  EOT
  type        = list(string)
  default     = ["platform-team"]
  nullable    = false
}

variable "resource_quota" {
  description = "Optional hard resource quota for the namespace. Null disables the quota."
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
  })
  default = null
}
