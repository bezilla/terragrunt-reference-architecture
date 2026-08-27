variable "cluster_name" {
  description = "Name of the EKS cluster to install add-ons on."
  type        = string
  nullable    = false
}

variable "addons" {
  description = <<-EOT
    Map of EKS managed add-ons to install, keyed by add-on name (e.g. "vpc-cni", "coredns",
    "kube-proxy", "aws-ebs-csi-driver"). Set version to null to let EKS pick the default for the
    cluster's Kubernetes version.
  EOT
  type = map(object({
    version                  = optional(string)
    service_account_role_arn = optional(string)
    configuration_values     = optional(string)
  }))
  default = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }
  nullable = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
