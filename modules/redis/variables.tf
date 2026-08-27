variable "name" {
  description = "Name of the ElastiCache replication group."
  type        = string
  nullable    = false
}

variable "engine_version" {
  description = "Redis engine version, e.g. \"7.1\"."
  type        = string
  default     = "7.1"
  nullable    = false
}

variable "node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.small"
  nullable    = false
}

variable "subnet_ids" {
  description = "Subnet IDs for the ElastiCache subnet group (private subnets)."
  type        = list(string)
  nullable    = false
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach."
  type        = list(string)
  nullable    = false
}

variable "replicas_per_node_group" {
  description = "Number of read replicas per shard."
  type        = number
  default     = 1
  nullable    = false
}

variable "num_node_groups" {
  description = "Number of shards (node groups). 1 disables cluster mode."
  type        = number
  default     = 1
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
