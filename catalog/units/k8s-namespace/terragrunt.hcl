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
generate "k8s_provider" {
  path      = "provider_k8s.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROV
data "aws_eks_cluster_auth" "this" {
  name = "${dependency.eks.outputs.cluster_name}"
}
provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
  token                  = data.aws_eks_cluster_auth.this.token
}
PROV
}
inputs = {
  namespace = values.namespace
}
