# Root Terragrunt configuration.
#
# Included by every unit via `include "root" { path = find_in_parent_folders("root.hcl") }`. It is
# named root.hcl (not terragrunt.hcl) because Terragrunt deprecates using a root terragrunt.hcl as
# shared config — a strict control now errors on it. This file is the single source of truth for:
#   - the S3 remote state backend (native locking, no DynamoDB — see docs/adr/0005)
#   - the generated AWS provider (default_tags, account guardrail, optional assume_role)
# It reads account.hcl / region.hcl / env.hcl from the directory hierarchy so that every value a
# new user must change lives in exactly one place.

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id  = local.account_vars.locals.account_id
  namespace   = local.account_vars.locals.namespace
  region      = local.region_vars.locals.aws_region
  environment = local.env_vars.locals.environment

  # Optional role to assume for deploys. Empty string => no assume_role block (e.g. local validate).
  deploy_role_arn   = lookup(local.account_vars.locals, "deploy_role_arn", "")
  assume_role_block = local.deploy_role_arn == "" ? "" : "  assume_role {\n    role_arn = \"${local.deploy_role_arn}\"\n  }\n"
}

# Default all IaC to OpenTofu. Terraform works as a drop-in (see docs/adr/0001).
terraform_binary = "tofu"

# Offline validation.
#
# `tofu init` for an S3 backend needs AWS credentials, so `terragrunt run --all validate` cannot
# reach the backend on a credential-less clean clone. Setting TG_DISABLE_BACKEND=true injects
# `-backend=false` into init, which lets validation run fully offline. Real plan/apply leave the
# variable unset and initialise the backend normally. `make validate` sets it for you.
terraform {
  extra_arguments "offline_backend_for_validate" {
    commands  = ["init"]
    arguments = get_env("TG_DISABLE_BACKEND", "false") == "true" ? ["-backend=false"] : []
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "tfstate-${local.account_id}-${local.region}"
    key          = "${path_relative_to_include()}/tofu.tfstate"
    region       = local.region
    encrypt      = true
    use_lockfile = true # S3 native locking; no DynamoDB table
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROVIDER
provider "aws" {
  region              = "${local.region}"
  allowed_account_ids = ["${local.account_id}"]

  default_tags {
    tags = {
      Namespace   = "${local.namespace}"
      Environment = "${local.environment}"
      ManagedBy   = "opentofu-terragrunt"
    }
  }
${local.assume_role_block}}
PROVIDER
}

inputs = {
  namespace   = local.namespace
  environment = local.environment
  region      = local.region
  account_id  = local.account_id
}
