variable "name" {
  description = "Name for the distribution and its web ACL."
  type        = string
  nullable    = false
}

variable "aliases" {
  description = "CNAMEs (domain names) served by the distribution."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate in us-east-1 for the aliases. Null uses the default CloudFront cert."
  type        = string
  default     = null
}

variable "origin_domain_name" {
  description = "Origin domain name (e.g. an ALB or S3 website endpoint)."
  type        = string
  nullable    = false
}

variable "origin_type" {
  description = "custom (ALB/HTTP origin) or s3 (REST origin with OAC)."
  type        = string
  default     = "custom"
  nullable    = false

  validation {
    condition     = contains(["custom", "s3"], var.origin_type)
    error_message = "origin_type must be custom or s3."
  }
}

variable "managed_rule_groups" {
  description = "AWS managed WAF rule groups to enable, in priority order."
  type        = list(string)
  default     = ["AWSManagedRulesCommonRuleSet", "AWSManagedRulesKnownBadInputsRuleSet", "AWSManagedRulesAmazonIpReputationList"]
  nullable    = false
}

variable "rate_limit" {
  description = "Requests per 5-minute window per IP before the rate-based rule blocks."
  type        = number
  default     = 2000
  nullable    = false
}

variable "log_bucket_domain_name" {
  description = "S3 bucket domain name for CloudFront access logs (must have log-delivery enabled). Null disables access logging."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags merged over the provider default_tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
