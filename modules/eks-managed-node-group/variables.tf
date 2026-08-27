variable "cluster_name" {
  description = "Name of the EKS cluster to attach the node group to."
  type        = string
  nullable    = false
}

variable "node_group_name" {
  description = "Name of the managed node group."
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "Private subnet IDs the nodes launch into."
  type        = list(string)
  nullable    = false
}

variable "instance_types" {
  description = "Candidate instance types for the node group."
  type        = list(string)
  default     = ["m6i.large"]
  nullable    = false
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT. See ADR-0006 for when SPOT (or Karpenter/Ocean) is worth it."
  type        = string
  default     = "ON_DEMAND"
  nullable    = false

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "desired_size" {
  description = "Desired node count."
  type        = number
  default     = 2
  nullable    = false
}

variable "min_size" {
  description = "Minimum node count."
  type        = number
  default     = 1
  nullable    = false
}

variable "max_size" {
  description = "Maximum node count."
  type        = number
  default     = 4
  nullable    = false
}

variable "disk_size_gb" {
  description = "EBS root volume size per node, in GiB."
  type        = number
  default     = 50
  nullable    = false
}

variable "labels" {
  description = "Kubernetes labels applied to nodes."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "taints" {
  description = "Kubernetes taints applied to nodes."
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string
  }))
  default  = []
  nullable = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
