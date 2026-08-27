locals {
  namespace    = "acme"
  account_id   = "123456789012"
  account_name = "management"

  # ARN of the role Terragrunt assumes to deploy into this account. Leave empty to use ambient
  # credentials (or for local `run --all validate`, which needs no AWS access at all).
  # Example: "arn:aws:iam::123456789012:role/terragrunt-deploy"
  deploy_role_arn = ""
}
