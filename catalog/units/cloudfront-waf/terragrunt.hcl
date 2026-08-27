# Catalog unit: cloudfront-waf.
#
# Demonstrates the us-east-1 *aliased* provider pattern: the module keeps the environment's regional
# default provider for the (global) distribution, and receives a us-east-1-aliased provider for the
# WAFv2 web ACL, which must be created in us-east-1 for CLOUDFRONT scope. The alias is generated
# here and satisfies the module's `configuration_aliases = [aws.us_east_1]`.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//modules/cloudfront-waf"
}

dependency "acm" {
  config_path = "../acm-certificate"
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

generate "provider_us_east_1" {
  path      = "provider_us_east_1.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROV
provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = ["${include.root.locals.account_id}"]

  default_tags {
    tags = {
      Namespace   = "${include.root.locals.namespace}"
      Environment = "${include.root.locals.environment}"
      ManagedBy   = "opentofu-terragrunt"
    }
  }
}
PROV
}

inputs = {
  name                = "${include.root.locals.namespace}-${include.root.locals.environment}-edge"
  aliases             = values.aliases
  acm_certificate_arn = dependency.acm.outputs.certificate_arn
  origin_domain_name  = values.origin_domain_name
  origin_type         = "custom"
}
