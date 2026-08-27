# Catalog unit: eks-addons. Depends on eks.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/eks-addons"
}
dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}
inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
}
