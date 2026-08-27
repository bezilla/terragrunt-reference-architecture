# eks-addons

EKS managed add-ons (CoreDNS, kube-proxy, VPC CNI, and anything else) driven by a single map, so environments differ by data rather than copied resource blocks. Conflicts resolve toward the declared config to correct manual drift.

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
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_addons"></a> [addons](#input\_addons) | Map of EKS managed add-ons to install, keyed by add-on name (e.g. "vpc-cni", "coredns",<br/>"kube-proxy", "aws-ebs-csi-driver"). Set version to null to let EKS pick the default for the<br/>cluster's Kubernetes version. | <pre>map(object({<br/>    version                  = optional(string)<br/>    service_account_role_arn = optional(string)<br/>    configuration_values     = optional(string)<br/>  }))</pre> | <pre>{<br/>  "coredns": {},<br/>  "kube-proxy": {},<br/>  "vpc-cni": {}<br/>}</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster to install add-ons on. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addon_versions"></a> [addon\_versions](#output\_addon\_versions) | Resolved version of each installed add-on. |
<!-- END_TF_DOCS -->
