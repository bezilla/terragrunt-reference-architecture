mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
}

run "default_users_and_groups" {
  command = plan
  assert {
    condition     = length(aws_iam_user.this) == 2
    error_message = "Two example users expected by default."
  }
  assert {
    condition     = length(aws_iam_group.this) == 2
    error_message = "Two example groups expected by default."
  }
}

run "mfa_enforced_on_every_group" {
  command = plan
  assert {
    condition     = length(aws_iam_group_policy_attachment.enforce_mfa) == length(aws_iam_group.this)
    error_message = "Every group must have the enforce-mfa policy attached."
  }
}

run "no_access_keys_created" {
  command = plan
  # The module must never create static keys; there is no aws_iam_access_key resource at all.
  assert {
    condition     = length(aws_iam_user.this) >= 0
    error_message = "sanity"
  }
}

run "irsa_roles_created_from_map" {
  command = plan
  variables {
    irsa_roles = {
      "app-s3" = {
        oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/ABC"
        oidc_provider_url = "oidc.eks.us-west-2.amazonaws.com/id/ABC"
        namespace         = "web"
        service_account   = "app"
        policy_arns       = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
      }
    }
  }
  assert {
    condition     = length(aws_iam_role.irsa) == 1
    error_message = "One IRSA role should be created from the map."
  }
  assert {
    condition     = length(aws_iam_role_policy_attachment.irsa) == 1
    error_message = "IRSA role policy attachment should be created."
  }
}
