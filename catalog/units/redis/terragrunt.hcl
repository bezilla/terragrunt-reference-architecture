# Catalog unit: redis. Depends on vpc (private subnets) and eks (cluster SG).
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/redis"
}
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    private_subnet_ids = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}
dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_security_group_id = "sg-mock000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}
inputs = {
  name                   = "${include.root.locals.namespace}-${include.root.locals.environment}-cache"
  subnet_ids             = dependency.vpc.outputs.private_subnet_ids
  vpc_security_group_ids = [dependency.eks.outputs.cluster_security_group_id]
  node_type              = values.node_type
}
