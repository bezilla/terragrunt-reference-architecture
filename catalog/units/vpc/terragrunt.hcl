# Catalog unit: vpc. No dependencies.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/vpc"
}
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}
inputs = {
  name               = "${include.root.locals.namespace}-${include.root.locals.environment}"
  cidr_block         = values.cidr_block
  azs                = values.azs
  private_subnets    = values.private_subnets
  public_subnets     = values.public_subnets
  database_subnets   = values.database_subnets
  single_nat_gateway = values.single_nat_gateway
  eks_cluster_name   = "${include.root.locals.namespace}-${include.root.locals.environment}-eks"
}
