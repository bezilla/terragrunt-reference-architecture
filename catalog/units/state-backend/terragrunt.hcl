# Catalog unit: state-backend.
#
# Note the deliberate exception: this unit does NOT include the root remote_state, because it
# *creates* the state bucket. It runs with local state during bootstrap, then its state is migrated
# in. See modules/state-backend/README.md.

terraform {
  source = "${get_repo_root()}//modules/state-backend"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

inputs = {
  bucket_name = "tfstate-${local.account_vars.locals.account_id}-${local.region_vars.locals.aws_region}"
}
