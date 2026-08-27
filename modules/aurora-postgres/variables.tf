variable "cluster_identifier" {
  description = "Identifier for the Aurora cluster."
  type        = string
  nullable    = false
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version, e.g. \"16.4\"."
  type        = string
  nullable    = false
}

variable "database_name" {
  description = "Name of the initial database created in the cluster."
  type        = string
  default     = "app"
  nullable    = false
}

variable "master_username" {
  description = "Master username. The password is generated and stored in Secrets Manager by RDS."
  type        = string
  default     = "dbadmin"
  nullable    = false
}

variable "subnet_group_name" {
  description = "DB subnet group name (typically the VPC module's database_subnet_group_name)."
  type        = string
  nullable    = false
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach to the cluster."
  type        = list(string)
  nullable    = false
}

variable "instance_count" {
  description = "Number of cluster instances (1 writer + N-1 readers)."
  type        = number
  default     = 2
  nullable    = false

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

variable "instance_class" {
  description = "Instance class for cluster members."
  type        = string
  default     = "db.r6g.large"
  nullable    = false
}

variable "backup_retention_days" {
  description = "Automated backup retention window, in days."
  type        = number
  default     = 14
  nullable    = false
}

variable "deletion_protection" {
  description = "Protect the cluster from deletion. Should be true in production."
  type        = bool
  default     = true
  nullable    = false
}

variable "global_cluster_identifier" {
  description = "Attach this cluster to an Aurora Global Database. Null for a standalone regional cluster."
  type        = string
  default     = null
}

variable "create_proxy" {
  description = "Create an RDS Proxy in front of the cluster. The proxy is the cutover seam for the blue/green upgrade pattern (see README)."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
