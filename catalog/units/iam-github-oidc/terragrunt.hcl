# Catalog unit: iam-github-oidc.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//modules/iam-github-oidc"
}

inputs = {
  # Replace with your GitHub org and the repo:ref patterns allowed to deploy.
  github_org   = "acme-corp"
  repositories = ["infrastructure:ref:refs/heads/main"]
  role_name    = "github-actions-deploy"
  policy_arns  = ["arn:aws:iam::aws:policy/PowerUserAccess"]
}
