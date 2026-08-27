variable "users" {
  description = <<-EOT
    Human IAM users to manage, keyed by username, each with the groups they belong to. This
    replaces the source system's existing_users.tf, which hard-coded individuals' names and email
    addresses as resource labels — here users are pure data with illustrative example values.

    Note: these users have NO access keys and NO console password set by this module. Access is via
    assuming roles (console federation or the CLI), never long-lived keys.
  EOT
  type = map(object({
    groups = list(string)
  }))
  default = {
    "alice.engineer" = { groups = ["engineers"] }
    "bob.operator"   = { groups = ["engineers", "billing-readonly"] }
  }
  nullable = false
}

variable "groups" {
  description = "IAM groups to manage, keyed by group name, each with a list of managed policy ARNs to attach."
  type = map(object({
    policy_arns = list(string)
  }))
  default = {
    "engineers"        = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
    "billing-readonly" = { policy_arns = ["arn:aws:iam::aws:policy/job-function/Billing"] }
  }
  nullable = false
}

variable "irsa_roles" {
  description = <<-EOT
    IAM Roles for Service Accounts (IRSA / Pod Identity). Each entry trusts an EKS OIDC provider
    for a specific Kubernetes service account, granting pods scoped AWS access without node-role
    sharing or static keys. Keyed by role name.
  EOT
  type = map(object({
    oidc_provider_arn = string
    oidc_provider_url = string
    namespace         = string
    service_account   = string
    policy_arns       = list(string)
  }))
  default  = {}
  nullable = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
