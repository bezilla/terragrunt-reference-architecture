# state-backend

Bootstrap module for the OpenTofu/Terraform remote state backend: a customer-managed KMS key and a locked-down, versioned S3 bucket. Uses **S3 native locking** (`use_lockfile`) — there is no DynamoDB lock table (see [ADR-0005](../../docs/adr/0005-s3-native-locking-over-dynamodb.md)).

## Bootstrap

This module stores the state for *all other* state, so it cannot store its own state in the bucket it creates. **Its state stays local, by design** — the catalog unit that instantiates it deliberately does not include the root config, and therefore generates no S3 backend at all.

Run it on its own, once per account, before anything else in that account:

```bash
cd live/<account>/<region>/<env>
terragrunt stack generate
(cd .terragrunt-stack/state-backend && terragrunt apply)   # local state
terragrunt run --all apply                                  # everything else, now that the bucket exists
```

**Why not migrate it into the bucket.** Migrating is the more common advice, and it is a reasonable
choice, but it is not the one this repository makes. The migration has to be done by hand — adding a
backend block the unit does not generate, then `tofu init -migrate-state` — and it leaves the bucket's
own state inside the bucket, so a bucket-destroying accident takes the record of the bucket with it.

The trade is deliberate: this is two resources that change almost never, and if the local state file
is lost they are recoverable by import rather than by rebuild:

```bash
tofu import aws_s3_bucket.state tfstate-<account-id>-<region>
tofu import aws_kms_key.state   <key-id>
```

Back the file up if you like, but losing it is an inconvenience, not an outage. If you prefer the
migration model, nothing here stops you — add the backend block and re-init; just do it consistently
and update the quickstart in the top-level README to match.

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
| [aws_kms_alias.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_public_access_block.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Globally-unique name for the S3 bucket that stores OpenTofu/Terraform state. | `string` | n/a | yes |
| <a name="input_noncurrent_version_retention_days"></a> [noncurrent\_version\_retention\_days](#input\_noncurrent\_version\_retention\_days) | How many days to retain noncurrent state versions before expiring them. | `number` | `90` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply, merged over the provider default\_tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the state bucket. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name/ID of the state bucket. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key encrypting state. |
<!-- END_TF_DOCS -->
