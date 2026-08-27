variable "zone_name" {
  description = "DNS zone name, e.g. \"example.com\" or \"internal.example.com\"."
  type        = string
  nullable    = false
}

variable "private_zone" {
  description = "Create a private hosted zone associated with a VPC instead of a public zone."
  type        = bool
  default     = false
  nullable    = false
}

variable "vpc_id" {
  description = "VPC to associate with a private zone. Required when private_zone = true."
  type        = string
  default     = null
}

variable "records" {
  description = <<-EOT
    DNS records to create in the zone, keyed by an arbitrary id. Each record has a name (relative
    or absolute), a type, a TTL, and a list of values. Alias records are out of scope for this
    simple module.
  EOT
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = list(string)
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
