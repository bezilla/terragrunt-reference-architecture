# Catalog unit: eks. Depends on vpc for private subnets.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/eks"
}
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    private_subnet_ids = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}
inputs = {
  cluster_name           = "${include.root.locals.namespace}-${include.root.locals.environment}-eks"
  kubernetes_version     = values.kubernetes_version
  subnet_ids             = dependency.vpc.outputs.private_subnet_ids
  endpoint_public_access = values.endpoint_public_access
}
