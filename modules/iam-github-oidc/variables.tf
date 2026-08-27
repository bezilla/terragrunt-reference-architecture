variable "github_org" {
  description = "GitHub organization or user that owns the repositories allowed to assume the role."
  type        = string
  nullable    = false
}

variable "repositories" {
  description = <<-EOT
    Repository + ref patterns allowed to assume the role, e.g. "infrastructure:ref:refs/heads/main"
    or "infrastructure:environment:prod". Each becomes a sub claim condition
    "repo:<org>/<pattern>". Scoping to specific branches/environments is what keeps this safe.
  EOT
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.repositories) > 0
    error_message = "Provide at least one repository:ref pattern."
  }
}

variable "role_name" {
  description = "Name of the IAM role that GitHub Actions assumes."
  type        = string
  default     = "github-actions"
  nullable    = false
}

variable "policy_arns" {
  description = "Managed policy ARNs to attach to the role. Scope these tightly — the deploy role's blast radius is whatever you attach here."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one (only one is allowed per account)."
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
