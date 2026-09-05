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
  # ReadOnlyAccess is the default ON PURPOSE, and it is not sufficient to apply.
  #
  # This unit previously attached PowerUserAccess, which made the example work end to
  # end and quietly contradicted everything this repository says about least privilege:
  # PowerUserAccess grants nearly all non-IAM actions across the whole account, so a
  # compromised workflow run could reach far past the resources these stacks manage.
  #
  # Defaulting to read-only means `plan` works out of the box and `apply` fails loudly
  # until someone consciously widens it. Widen it to the resources your stacks actually
  # manage -- not to a blanket managed policy. Scoping a real deploy role is an exercise
  # this repository documents rather than performs; see the "Reference boundary" section
  # of the top-level README.
  policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
