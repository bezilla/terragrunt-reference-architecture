# redis

Redis via ElastiCache replication group, with encryption at rest and in transit always on, automatic failover and Multi-AZ when replicas are present, and optional cluster mode (sharding). Snapshots retained 7 days.

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
| [aws_elasticache_replication_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Redis engine version, e.g. "7.1". | `string` | `"7.1"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the ElastiCache replication group. | `string` | n/a | yes |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | ElastiCache node type. | `string` | `"cache.t4g.small"` | no |
| <a name="input_num_node_groups"></a> [num\_node\_groups](#input\_num\_node\_groups) | Number of shards (node groups). 1 disables cluster mode. | `number` | `1` | no |
| <a name="input_replicas_per_node_group"></a> [replicas\_per\_node\_group](#input\_replicas\_per\_node\_group) | Number of read replicas per shard. | `number` | `1` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the ElastiCache subnet group (private subnets). | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | Security group IDs to attach. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_configuration_endpoint_address"></a> [configuration\_endpoint\_address](#output\_configuration\_endpoint\_address) | Configuration endpoint (cluster-mode-enabled) address. |
| <a name="output_primary_endpoint_address"></a> [primary\_endpoint\_address](#output\_primary\_endpoint\_address) | Primary endpoint (cluster-mode-disabled) address. |
<!-- END_TF_DOCS -->
