mock_provider "aws" {}

variables {
  cluster_name = "acme-prod-eks"
}

run "default_three_core_addons" {
  command = plan
  assert {
    condition     = length(aws_eks_addon.this) == 3
    error_message = "Default install is coredns, kube-proxy, vpc-cni (3)."
  }
}

run "extra_addon_added" {
  command = plan
  variables {
    addons = {
      coredns            = {}
      kube-proxy         = {}
      vpc-cni            = {}
      aws-ebs-csi-driver = {}
    }
  }
  assert {
    condition     = length(aws_eks_addon.this) == 4
    error_message = "An extra add-on in the map should be installed."
  }
}
