# postgres-roles

In-database roles, logical databases, and generated credentials on a **shared** Aurora cluster — one cluster hosting many application databases, each with its own owning role and a generated password stored in SSM Parameter Store (SecureString). Uses the `cyrilgdn/postgresql` provider (configured by the caller). A shared-cluster, many-databases data pattern.

**Not wired into the reference stacks, on purpose.** Every other module here has a
`catalog/units/` entry and appears in a `live/` stack; this one does not. The `cyrilgdn/postgresql`
provider authenticates against a *running* database, so even `plan` needs network reachability to a
live Aurora cluster and a working credential — neither of which exists in a credential-free offline
validation, which is the bar every unit in this repo has to clear. It ships as a module you can
adopt once you have a cluster to point it at: add a unit that depends on `aurora-postgres`, pass the
cluster endpoint and master credential into the provider, and apply it from somewhere with network
access to the cluster (a bastion, a runner in the VPC, or a Kubernetes job) rather than from CI.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_postgresql"></a> [postgresql](#requirement\_postgresql) | ~> 1.25 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.62.0 |
| <a name="provider_postgresql"></a> [postgresql](#provider\_postgresql) | 1.27.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [postgresql_database.this](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/database) | resource |
| [postgresql_role.owner](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/role) | resource |
| [random_password.role](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_databases"></a> [databases](#input\_databases) | Logical databases to create on a shared Aurora cluster, each with an owner role. Keyed by<br/>database name. This is the "one cluster, many application databases" pattern: cheaper than a<br/>cluster per service, with per-application credentials and isolation via roles. | <pre>map(object({<br/>    owner_role = string<br/>  }))</pre> | n/a | yes |
| <a name="input_secret_prefix"></a> [secret\_prefix](#input\_secret\_prefix) | SSM Parameter Store path prefix under which generated role credentials are stored. | `string` | `"/acme/databases"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged over the provider default\_tags (applied to SSM parameters). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_database_names"></a> [database\_names](#output\_database\_names) | Names of the created logical databases. |
| <a name="output_password_parameter_names"></a> [password\_parameter\_names](#output\_password\_parameter\_names) | SSM parameter names holding each role's generated password. |
<!-- END_TF_DOCS -->
