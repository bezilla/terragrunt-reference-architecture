# Catalog unit: aurora-postgres. Depends on vpc (subnet group) and eks (cluster SG for access).
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/aurora-postgres"
}
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    database_subnet_group_name = "mock-db-subnet-group"
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
  cluster_identifier     = "${include.root.locals.namespace}-${include.root.locals.environment}-core"
  engine_version         = values.engine_version
  subnet_group_name      = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [dependency.eks.outputs.cluster_security_group_id]
  instance_count         = values.instance_count
  instance_class         = values.instance_class
  deletion_protection    = values.deletion_protection
}
