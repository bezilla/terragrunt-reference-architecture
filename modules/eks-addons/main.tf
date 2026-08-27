# EKS managed add-ons.
#
# The core add-ons (CoreDNS, kube-proxy, VPC CNI) plus anything else the caller passes, driven by
# a single map so environments differ by data, not by copied resource blocks. Conflicts on
# create/update resolve toward the Terraform-declared config so drift from manual kubectl edits is
# corrected on the next apply.

resource "aws_eks_addon" "this" {
  for_each = var.addons

  cluster_name  = var.cluster_name
  addon_name    = each.key
  addon_version = each.value.version

  service_account_role_arn = each.value.service_account_role_arn
  configuration_values     = each.value.configuration_values

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}
