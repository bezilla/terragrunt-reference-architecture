# Catalog unit: acm-certificate (edge / CloudFront cert).
#
# CloudFront requires its ACM certificate in us-east-1, regardless of where the rest of the
# environment runs. Same us-east-1 aliased-provider pattern as the cloudfront-waf unit: keep the
# root-generated regional default provider, and add a us-east-1 alias that satisfies the module's
# `configuration_aliases = [aws.us_east_1]`.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//modules/acm-certificate"
}

dependency "dns" {
  config_path = "../route53-zone"
  mock_outputs = {
    zone_id = "Z0000000000000000MOCK"
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
  domain_name               = values.domain_name
  subject_alternative_names = values.subject_alternative_names
  route53_zone_id           = dependency.dns.outputs.zone_id
}
