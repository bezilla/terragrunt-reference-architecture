mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_eks_cluster" {
    defaults = {
      identity              = [{ oidc = [{ issuer = "https://oidc.eks.us-west-2.amazonaws.com/id/MOCK000" }] }]
      certificate_authority = [{ data = "bW9jaw==" }]
    }
  }
}
mock_provider "tls" {}

variables {
  cluster_name       = "acme-prod-eks"
  kubernetes_version = "1.34"
  subnet_ids         = ["subnet-a", "subnet-b", "subnet-c"]
}

run "private_endpoint_by_default" {
  command = plan
  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == false
    error_message = "API endpoint must be private by default."
  }
}

run "secret_encryption_enabled" {
  command = plan
  assert {
    condition     = length(aws_eks_cluster.this.encryption_config) == 1
    error_message = "Secret envelope encryption must be configured."
  }
}

run "no_admin_access_entries_by_default" {
  command = plan
  assert {
    condition     = length(aws_eks_access_entry.admin) == 0
    error_message = "No access entries unless admin principals are given."
  }
}

run "admin_access_entries_created" {
  command = plan
  variables {
    cluster_admin_principal_arns = ["arn:aws:iam::123456789012:role/admins"]
  }
  assert {
    condition     = length(aws_eks_access_entry.admin) == 1 && length(aws_eks_access_policy_association.admin) == 1
    error_message = "An access entry and policy association per admin principal."
  }
}
