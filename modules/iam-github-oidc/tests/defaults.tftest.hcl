# Plan-mode tests with a mocked provider — no credentials, no apply.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  github_org   = "acme-corp"
  repositories = ["infrastructure:ref:refs/heads/main"]
}

run "creates_oidc_provider_by_default" {
  command = plan
  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "OIDC provider should be created by default."
  }
  assert {
    condition     = length(data.aws_iam_openid_connect_provider.existing) == 0
    error_message = "Existing-provider lookup should be inactive when creating one."
  }
}

run "reuses_existing_provider_when_disabled" {
  command = plan
  variables {
    create_oidc_provider = false
  }
  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "OIDC provider should not be created when create_oidc_provider = false."
  }
  assert {
    condition     = length(data.aws_iam_openid_connect_provider.existing) == 1
    error_message = "Should look up the existing provider when create_oidc_provider = false."
  }
}

run "attaches_all_policies" {
  command = plan
  variables {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
    ]
  }
  assert {
    condition     = length(aws_iam_role_policy_attachment.github) == 2
    error_message = "Both managed policies should be attached."
  }
}

run "session_duration_capped_at_one_hour" {
  command = plan
  assert {
    condition     = aws_iam_role.github.max_session_duration == 3600
    error_message = "Deploy role session should be capped at 1 hour."
  }
}
