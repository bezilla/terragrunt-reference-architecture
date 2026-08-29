# cloudfront-waf

CloudFront distribution fronted by a WAFv2 web ACL (AWS managed rule groups + a per-IP rate limit). TLS pinned to TLSv1.2_2021, HTTP redirected to HTTPS, supports both custom (ALB) and S3-with-OAC origins. Uses AWS managed rules in place of a hand-maintained reputation-list Lambda. The WAF web ACL is created in us-east-1 via a required aliased provider (`aws.us_east_1`). Multi-vendor edge is discussed in an ADR rather than shipped.

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
| <a name="provider_aws.us_east_1"></a> [aws.us\_east\_1](#provider\_aws.us\_east\_1) | 6.62.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ARN of an ACM certificate in us-east-1 for the aliases. Null uses the default CloudFront cert. | `string` | `null` | no |
| <a name="input_aliases"></a> [aliases](#input\_aliases) | CNAMEs (domain names) served by the distribution. | `list(string)` | `[]` | no |
| <a name="input_log_bucket_domain_name"></a> [log\_bucket\_domain\_name](#input\_log\_bucket\_domain\_name) | S3 bucket domain name for CloudFront access logs (must have log-delivery enabled). Null disables access logging. | `string` | `null` | no |
| <a name="input_managed_rule_groups"></a> [managed\_rule\_groups](#input\_managed\_rule\_groups) | AWS managed WAF rule groups to enable, in priority order. | `list(string)` | <pre>[<br/>  "AWSManagedRulesCommonRuleSet",<br/>  "AWSManagedRulesKnownBadInputsRuleSet",<br/>  "AWSManagedRulesAmazonIpReputationList"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the distribution and its web ACL. | `string` | n/a | yes |
| <a name="input_origin_domain_name"></a> [origin\_domain\_name](#input\_origin\_domain\_name) | Origin domain name (e.g. an ALB or S3 website endpoint). | `string` | n/a | yes |
| <a name="input_origin_type"></a> [origin\_type](#input\_origin\_type) | custom (ALB/HTTP origin) or s3 (REST origin with OAC). | `string` | `"custom"` | no |
| <a name="input_rate_limit"></a> [rate\_limit](#input\_rate\_limit) | Requests per 5-minute window per IP before the rate-based rule blocks. | `number` | `2000` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | CloudFront distribution domain name (for DNS aliasing). |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | CloudFront distribution ID. |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the WAFv2 web ACL. |
<!-- END_TF_DOCS -->
