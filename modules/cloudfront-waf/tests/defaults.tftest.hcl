mock_provider "aws" {}
mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  name               = "acme-prod-edge"
  origin_domain_name = "origin.example.com"
}

run "waf_rules_are_managed_groups_plus_rate_limit" {
  command = plan
  # three managed groups by default + one rate-limit rule
  assert {
    condition     = length(aws_wafv2_web_acl.this.rule) == 4
    error_message = "Expected 3 managed rule groups + 1 rate-limit rule."
  }
}

run "custom_origin_has_no_oac" {
  command = plan
  assert {
    condition     = length(aws_cloudfront_origin_access_control.this) == 0
    error_message = "A custom (ALB) origin must not create an OAC."
  }
}

run "s3_origin_creates_oac" {
  command = plan
  variables {
    origin_type = "s3"
  }
  assert {
    condition     = length(aws_cloudfront_origin_access_control.this) == 1
    error_message = "An S3 origin must create an Origin Access Control."
  }
}

run "logging_off_without_bucket" {
  command = plan
  assert {
    condition     = length(aws_cloudfront_distribution.this.logging_config) == 0
    error_message = "Access logging should be off when no log bucket is supplied."
  }
}
