# k8s-namespace

Kubernetes namespace with baseline RBAC (editor groups bound to the built-in `edit` ClusterRole) and an optional resource quota. Namespace owners are generic RBAC group subjects, not hard-coded people.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.8 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.30 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_resource_quota.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/resource_quota) | resource |
| [kubernetes_role_binding.editors](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_editor_group_subjects"></a> [editor\_group\_subjects](#input\_editor\_group\_subjects) | RBAC subjects granted edit rights in the namespace. Each is a Kubernetes group name, typically<br/>mapped from an IAM role via EKS access entries. Defaults are illustrative. | `list(string)` | <pre>[<br/>  "platform-team"<br/>]</pre> | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the namespace. | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Name of the Kubernetes namespace to create. | `string` | n/a | yes |
| <a name="input_owner_team"></a> [owner\_team](#input\_owner\_team) | Owning team label, for cost/allocation and paging lookups. | `string` | `"platform-team"` | no |
| <a name="input_resource_quota"></a> [resource\_quota](#input\_resource\_quota) | Optional hard resource quota for the namespace. Null disables the quota. | <pre>object({<br/>    requests_cpu    = string<br/>    requests_memory = string<br/>    limits_cpu      = string<br/>    limits_memory   = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Name of the created namespace. |
<!-- END_TF_DOCS -->
