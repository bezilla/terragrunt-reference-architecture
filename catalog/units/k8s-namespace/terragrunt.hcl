# Catalog unit: k8s-namespace. Depends on eks and generates a kubernetes provider wired to it.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/k8s-namespace"
}
dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}
# The kubernetes provider is generated here (not in root.hcl) because only Kubernetes units need it.
# This unit takes no AWS provider -- see unit.hcl beside this file, and docs/adr/0012.
generate "k8s_provider" {
  path      = "provider_k8s.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROV
provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

  # The token comes from the AWS CLI, not from an aws_eks_cluster_auth data source. That data
  # source was the only reason this Kubernetes-only unit needed the AWS provider at all, and it
  # also resolves at plan time and lands a 15-minute token in state. exec fetches one per
  # invocation instead. It needs the `aws` CLI on PATH wherever plan/apply runs.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", "${dependency.eks.outputs.cluster_name}",
      "--region", "${include.root.locals.region}",
    ]
  }
}
PROV
}
inputs = {
  namespace = values.namespace
}
