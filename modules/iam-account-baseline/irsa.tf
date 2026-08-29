# IAM Roles for Service Accounts (IRSA).
#
# The keyless-workload pattern: instead of static access keys handed to applications, pods assume
# a role scoped to their exact namespace/serviceaccount via the cluster's OIDC provider.

data "aws_iam_policy_document" "irsa_assume_role" {
  for_each = var.irsa_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [each.value.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${each.value.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${each.value.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = var.irsa_roles

  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role[each.key].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = {
    for pair in flatten([
      for rname, r in var.irsa_roles : [
        for arn in r.policy_arns : {
          key  = "${rname}:${arn}"
          role = rname
          arn  = arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.irsa[each.value.role].name
  policy_arn = each.value.arn
}
