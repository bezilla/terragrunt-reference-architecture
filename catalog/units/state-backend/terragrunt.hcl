# Catalog unit: state-backend.
#
# Instantiated only by the per-account bootstrap units under live/<account>/<region>/bootstrap/,
# and by no terragrunt.stack.hcl. It creates the bucket that every other unit's backend lives in,
# so it cannot be a member of the stacks that depend on it: `stack generate` materialises
# .terragrunt-stack/, which is gitignored and removed by `make clean`, so a bootstrap state kept
# there is gone by the next checkout -- and the next `run --all apply` would try to recreate a
# bucket and a KMS key that already exist. The bootstrap units are hand-written directories for
# that reason: nothing generates them, so nothing deletes them.
#
# Deliberate exception: this unit does NOT `include "root"`. Including root would configure a
# backend in the very bucket this unit creates (a chicken-and-egg). It therefore generates its own
# local backend, and its own AWS provider rather than inheriting root's.
#
# Its state is local permanently -- not "for now". See docs/adr/0011 for where that state lives and
# what it costs, and modules/state-backend/README.md for the import-based recovery when it is lost.

terraform {
  source = "${get_repo_root()}//modules/state-backend"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_id   = local.account_vars.locals.account_id
  region       = local.region_vars.locals.aws_region
}

# Pin the state file to the bootstrap unit's own directory under live/. Terragrunt runs OpenTofu
# inside .terragrunt-cache, so a backend left at its default would write the state there and lose
# it to the next `make clean`. get_terragrunt_dir() is the including unit's directory, which is
# tracked, stable, and outside every generated tree.
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<BACKEND
terraform {
  backend "local" {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}
BACKEND
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
