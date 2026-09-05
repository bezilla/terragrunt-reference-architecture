variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  nullable    = false
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane, e.g. \"1.34\"."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^1\\.(2[5-9]|3[0-9])$", var.kubernetes_version))
    error_message = "kubernetes_version must look like 1.25 .. 1.39."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs for the control-plane ENIs and worker networking (private subnets)."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API server is reachable from the public internet."
  type        = bool
  default     = false
  nullable    = false
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (only used when endpoint_public_access = true)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster-admin via EKS access entries (replaces the aws-auth ConfigMap)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "enabled_log_types" {
  description = "Control-plane log types to ship to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  nullable    = false
}

variable "log_retention_days" {
  description = "Retention for the control-plane CloudWatch log group, in days."
  type        = number
  default     = 90
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
