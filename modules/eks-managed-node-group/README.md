# eks-managed-node-group

EKS **managed** node group with a launch template that enforces IMDSv2 and encrypted gp3 root volumes, SSM access, spot/on-demand capacity, labels/taints, and cluster-autoscaler-friendly `ignore_changes` on desired size. Managed node groups only — see [ADR-0006](../../docs/adr/0006-eks-managed-node-groups.md) for when self-managed ASGs or Karpenter/Ocean earn their place.

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
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_iam_policy_document.node_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_capacity_type"></a> [capacity\_type](#input\_capacity\_type) | ON\_DEMAND or SPOT. See ADR-0006 for when SPOT (or Karpenter/Ocean) is worth it. | `string` | `"ON_DEMAND"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster to attach the node group to. | `string` | n/a | yes |
| <a name="input_desired_size"></a> [desired\_size](#input\_desired\_size) | Desired node count. | `number` | `2` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | EBS root volume size per node, in GiB. | `number` | `50` | no |
| <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types) | Candidate instance types for the node group. | `list(string)` | <pre>[<br/>  "m6i.large"<br/>]</pre> | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Kubernetes labels applied to nodes. | `map(string)` | `{}` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum node count. | `number` | `4` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum node count. | `number` | `1` | no |
| <a name="input_node_group_name"></a> [node\_group\_name](#input\_node\_group\_name) | Name of the managed node group. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private subnet IDs the nodes launch into. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |
| <a name="input_taints"></a> [taints](#input\_taints) | Kubernetes taints applied to nodes. | <pre>list(object({<br/>    key    = string<br/>    value  = optional(string)<br/>    effect = string<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_node_group_arn"></a> [node\_group\_arn](#output\_node\_group\_arn) | ARN of the managed node group. |
| <a name="output_node_role_arn"></a> [node\_role\_arn](#output\_node\_role\_arn) | ARN of the IAM role assumed by the nodes. |
| <a name="output_node_role_name"></a> [node\_role\_name](#output\_node\_role\_name) | Name of the node IAM role (for attaching extra policies). |
<!-- END_TF_DOCS -->
