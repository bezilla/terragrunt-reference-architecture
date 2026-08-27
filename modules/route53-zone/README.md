# route53-zone

Route53 hosted zone (public or private) with a map-driven set of DNS records.

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
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_private_zone"></a> [private\_zone](#input\_private\_zone) | Create a private hosted zone associated with a VPC instead of a public zone. | `bool` | `false` | no |
| <a name="input_records"></a> [records](#input\_records) | DNS records to create in the zone, keyed by an arbitrary id. Each record has a name (relative<br/>or absolute), a type, a TTL, and a list of values. Alias records are out of scope for this<br/>simple module. | <pre>map(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = optional(number, 300)<br/>    records = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC to associate with a private zone. Required when private\_zone = true. | `string` | `null` | no |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | DNS zone name, e.g. "example.com" or "internal.example.com". | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Authoritative name servers (public zones). |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Hosted zone ID. |
<!-- END_TF_DOCS -->
