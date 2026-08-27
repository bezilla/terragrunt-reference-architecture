# iam-github-oidc

GitHub Actions → AWS via OIDC: short-lived tokens per workflow run, trust scoped to specific repositories and refs through the `sub` claim. **This is the replacement for long-lived `aws_iam_access_key` resources** — no static credentials anywhere. Attach deployment policies via `policy_arns` (scope them tightly).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.62.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_openid_connect_provider.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_oidc_provider"></a> [create\_oidc\_provider](#input\_create\_oidc\_provider) | Create the GitHub OIDC provider. Set false if the account already has one (only one is allowed per account). | `bool` | `true` | no |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organization or user that owns the repositories allowed to assume the role. | `string` | n/a | yes |
| <a name="input_policy_arns"></a> [policy\_arns](#input\_policy\_arns) | Managed policy ARNs to attach to the role. Scope these tightly — the deploy role's blast radius is whatever you attach here. | `list(string)` | `[]` | no |
| <a name="input_repositories"></a> [repositories](#input\_repositories) | Repository + ref patterns allowed to assume the role, e.g. "infrastructure:ref:refs/heads/main"<br/>or "infrastructure:environment:prod". Each becomes a sub claim condition<br/>"repo:<org>/<pattern>". Scoping to specific branches/environments is what keeps this safe. | `list(string)` | n/a | yes |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role that GitHub Actions assumes. | `string` | `"github-actions"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitHub OIDC provider. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the role GitHub Actions assumes (the value for role-to-assume in the workflow). |
<!-- END_TF_DOCS -->
