variable "domain_name" {
  description = "Primary fully-qualified domain name for the certificate."
  type        = string
  nullable    = false
}

variable "subject_alternative_names" {
  description = "Additional SANs (e.g. wildcard) to include on the certificate."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "route53_zone_id" {
  description = "Hosted zone ID in which to create the DNS validation records."
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
