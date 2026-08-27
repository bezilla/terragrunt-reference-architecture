# aurora-postgres

Aurora PostgreSQL cluster with RDS-managed master credentials in Secrets Manager (no password in state or tfvars), customer-managed KMS storage encryption, Performance Insights, enhanced monitoring, and an optional RDS Proxy. Ships native `tofu test` coverage (`tests/defaults.tftest.hcl`, mocked provider — runs with no credentials).

## Blue/green major-version upgrades
Enable `create_proxy = true`. To upgrade across a major version: stand up a **green** cluster with this same module (new `cluster_identifier`, restored from a snapshot of blue), validate it, then repoint the RDS Proxy target from the blue cluster to green and decommission blue. The proxy endpoint applications use never changes. Aurora Global Database is available via `global_cluster_identifier` — see [ADR](../../docs/adr/).

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
| [aws_db_proxy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_proxy) | resource |
| [aws_db_proxy_default_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_proxy_default_target_group) | resource |
| [aws_db_proxy_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_proxy_target) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_rds_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/db_subnet_group) | data source |
| [aws_iam_policy_document.monitoring_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.proxy_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Automated backup retention window, in days. | `number` | `14` | no |
| <a name="input_cluster_identifier"></a> [cluster\_identifier](#input\_cluster\_identifier) | Identifier for the Aurora cluster. | `string` | n/a | yes |
| <a name="input_create_proxy"></a> [create\_proxy](#input\_create\_proxy) | Create an RDS Proxy in front of the cluster. The proxy is the cutover seam for the blue/green upgrade pattern (see README). | `bool` | `false` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the initial database created in the cluster. | `string` | `"app"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Protect the cluster from deletion. Should be true in production. | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Aurora PostgreSQL engine version, e.g. "16.4". | `string` | n/a | yes |
| <a name="input_global_cluster_identifier"></a> [global\_cluster\_identifier](#input\_global\_cluster\_identifier) | Attach this cluster to an Aurora Global Database. Null for a standalone regional cluster. | `string` | `null` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Instance class for cluster members. | `string` | `"db.r6g.large"` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of cluster instances (1 writer + N-1 readers). | `number` | `2` | no |
| <a name="input_master_username"></a> [master\_username](#input\_master\_username) | Master username. The password is generated and stored in Secrets Manager by RDS. | `string` | `"dbadmin"` | no |
| <a name="input_subnet_group_name"></a> [subnet\_group\_name](#input\_subnet\_group\_name) | DB subnet group name (typically the VPC module's database\_subnet\_group\_name). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags. | `map(string)` | `{}` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | Security group IDs to attach to the cluster. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the cluster. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Writer endpoint for the cluster. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | Secrets Manager ARN holding the RDS-managed master credentials. |
| <a name="output_proxy_endpoint"></a> [proxy\_endpoint](#output\_proxy\_endpoint) | RDS Proxy endpoint, or null when the proxy is disabled. |
| <a name="output_reader_endpoint"></a> [reader\_endpoint](#output\_reader\_endpoint) | Reader (load-balanced) endpoint for the cluster. |
<!-- END_TF_DOCS -->
