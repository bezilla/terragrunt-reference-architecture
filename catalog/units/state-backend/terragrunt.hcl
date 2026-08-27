# Catalog unit: state-backend.
#
# Deliberate exception: this unit does NOT `include "root"`, because it *creates* the S3 bucket that
# every other unit's backend lives in. Including root would try to configure that backend before it
# exists (a chicken-and-egg). It therefore runs with local state during bootstrap (later migrated in
# — see modules/state-backend/README.md), and because it skips root it must generate its own AWS
# provider rather than inheriting the one root generates.

terraform {
  source = "${get_repo_root()}//modules/state-backend"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_id   = local.account_vars.locals.account_id
  region       = local.region_vars.locals.aws_region
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROV
provider "aws" {
  region              = "${local.region}"
  allowed_account_ids = ["${local.account_id}"]

  default_tags {
    tags = {
      Namespace = "${local.account_vars.locals.namespace}"
      ManagedBy = "opentofu-terragrunt"
    }
  }
}
PROV
}

inputs = {
  bucket_name = "tfstate-${local.account_id}-${local.region}"
}
