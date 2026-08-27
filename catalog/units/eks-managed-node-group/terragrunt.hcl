# Catalog unit: eks-managed-node-group. Depends on eks (cluster) and vpc (subnets).
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/eks-managed-node-group"
}
dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    private_subnet_ids = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}
inputs = {
  cluster_name    = dependency.eks.outputs.cluster_name
  node_group_name = "default"
  subnet_ids      = dependency.vpc.outputs.private_subnet_ids
  instance_types  = values.instance_types
  capacity_type   = values.capacity_type
  desired_size    = values.desired_size
  min_size        = values.min_size
  max_size        = values.max_size
}
