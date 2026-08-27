variable "name" {
  description = "Name prefix for the VPC and its subnets (typically \"<namespace>-<environment>\")."
  type        = string
  nullable    = false
}

variable "cidr_block" {
  description = "Primary IPv4 CIDR block for the VPC."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR, e.g. 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across. Three is the recommended minimum for production."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Provide at least two availability zones."
  }
}

variable "private_subnets" {
  description = "CIDR blocks for private (workload) subnets, one per AZ."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "public_subnets" {
  description = "CIDR blocks for public (load-balancer / NAT) subnets, one per AZ."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "database_subnets" {
  description = "CIDR blocks for isolated database subnets, one per AZ."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway (cheaper, non-HA) instead of one per AZ. Set false in production."
  type        = bool
  default     = false
  nullable    = false
}

variable "eks_cluster_name" {
  description = "Optional EKS cluster name. When set, subnets are tagged for Kubernetes load-balancer discovery."
  type        = string
  default     = null
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs. Recommended on; toggleable for cost-sensitive sandboxes."
  type        = bool
  default     = true
  nullable    = false
}

variable "flow_log_retention_days" {
  description = "Retention for the VPC Flow Logs CloudWatch log group, in days."
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
