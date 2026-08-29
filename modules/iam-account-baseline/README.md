# iam-account-baseline

Account IAM baseline, entirely data-driven: human users and groups (from map variables with illustrative defaults — **no individuals baked in as resource labels**), MFA enforced across all groups, and IRSA/Pod-Identity roles so pods assume scoped roles via the EKS OIDC provider instead of using static keys. No access keys or console passwords are set by this module.

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
| [aws_iam_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group) | resource |
| [aws_iam_group_policy_attachment.enforce_mfa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy_attachment) | resource |
| [aws_iam_group_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy_attachment) | resource |
| [aws_iam_policy.enforce_mfa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_group_membership.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_group_membership) | resource |
| [aws_iam_policy_document.enforce_mfa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.irsa_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_groups"></a> [groups](#input\_groups) | IAM groups to manage, keyed by group name, each with a list of managed policy ARNs to attach. | <pre>map(object({<br/>    policy_arns = list(string)<br/>  }))</pre> | <pre>{<br/>  "billing-readonly": {<br/>    "policy_arns": [<br/>      "arn:aws:iam::aws:policy/job-function/Billing"<br/>    ]<br/>  },<br/>  "engineers": {<br/>    "policy_arns": [<br/>      "arn:aws:iam::aws:policy/ReadOnlyAccess"<br/>    ]<br/>  }<br/>}</pre> | no |
| <a name="input_irsa_roles"></a> [irsa\_roles](#input\_irsa\_roles) | IAM Roles for Service Accounts (IRSA / Pod Identity). Each entry trusts an EKS OIDC provider<br/>for a specific Kubernetes service account, granting pods scoped AWS access without node-role<br/>sharing or static keys. Keyed by role name. | <pre>map(object({<br/>    oidc_provider_arn = string<br/>    oidc_provider_url = string<br/>    namespace         = string<br/>    service_account   = string<br/>    policy_arns       = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | Human IAM users to manage, keyed by username, each with the groups they belong to. Users are<br/>pure data with illustrative example values — no individual's name or email is baked into the<br/>module as a resource label.<br/><br/>Note: these users have NO access keys and NO console password set by this module. Access is via<br/>assuming roles (console federation or the CLI), never long-lived keys. | <pre>map(object({<br/>    groups = list(string)<br/>  }))</pre> | <pre>{<br/>  "alice.engineer": {<br/>    "groups": [<br/>      "engineers"<br/>    ]<br/>  },<br/>  "bob.operator": {<br/>    "groups": [<br/>      "engineers",<br/>      "billing-readonly"<br/>    ]<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_group_names"></a> [group\_names](#output\_group\_names) | Names of the managed IAM groups. |
| <a name="output_irsa_role_arns"></a> [irsa\_role\_arns](#output\_irsa\_role\_arns) | ARNs of the created IRSA roles, keyed by role name. |
| <a name="output_user_names"></a> [user\_names](#output\_user\_names) | Names of the managed IAM users. |
<!-- END_TF_DOCS -->
