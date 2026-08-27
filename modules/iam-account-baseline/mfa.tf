# Enforce MFA across all managed groups.
#
# Denies everything except the handful of actions a user needs to sign in and enrol/manage their
# own MFA device, unless the session was authenticated with MFA. This is the standard AWS "force
# MFA" baseline and satisfies the account's second-factor requirement without a separate process.

data "aws_iam_policy_document" "enforce_mfa" {
  statement {
    sid       = "AllowViewAccountInfo"
    effect    = "Allow"
    actions   = ["iam:GetAccountPasswordPolicy", "iam:ListVirtualMFADevices"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowManageOwnMfa"
    effect = "Allow"
    actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ResyncMFADevice",
      "iam:DeactivateMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:GetUser",
      "iam:ChangePassword",
    ]
    resources = [
      "arn:aws:iam::*:mfa/&{aws:username}",
      "arn:aws:iam::*:user/&{aws:username}",
    ]
  }

  statement {
    sid    = "DenyAllExceptMfaSetupUnlessMfaPresent"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "iam:GetUser",
      "iam:ChangePassword",
      "sts:GetSessionToken",
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "enforce_mfa" {
  name   = "enforce-mfa"
  policy = data.aws_iam_policy_document.enforce_mfa.json
  tags   = var.tags
}

resource "aws_iam_group_policy_attachment" "enforce_mfa" {
  for_each = var.groups

  group      = aws_iam_group.this[each.key].name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}
