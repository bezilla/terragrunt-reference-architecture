# Terragrunt + OpenTofu Reference Architecture

A production-shaped AWS platform expressed as reusable OpenTofu modules and Terragrunt stacks —
EKS, Aurora PostgreSQL, a CloudFront/WAF edge, Datadog monitoring, and keyless CI, isolated across
management/staging/prod accounts. It is meant to be read as much as run: design decisions are
written down, not just implemented.

Derived from a production system and fully sanitized — every value is a placeholder.

## What it provisions

| Layer | Modules |
|---|---|
| Networking | `vpc` (3-tier subnets, NAT, gateway endpoints, flow logs) |
| Compute | `eks` (OIDC, access entries, secret encryption), `eks-managed-node-group`, `eks-addons`, `k8s-namespace` |
| Data | `aurora-postgres` (Secrets Manager creds, RDS Proxy, Global DB flag), `postgres-roles`, `redis` |
| Edge | `route53-zone`, `acm-certificate`, `cloudfront-waf` |
| Observability | `datadog-monitors` |
| Identity & state | `state-backend`, `iam-github-oidc`, `iam-account-baseline` |

See [docs/architecture.md](docs/architecture.md) for the diagram and request path.

## How it's structured

```
modules/            reusable OpenTofu modules (each: tf + versions + README + lockfile)
catalog/units/      reusable Terragrunt unit definitions that source the modules
live/               environment instantiation
  root.hcl            single root config: S3 backend, generated provider, tofu binary
  <account>/          account.hcl (id, deploy role) + region.hcl + env.hcl
    <region>/<env>/   terragrunt.stack.hcl — instantiates catalog units with per-env values
docs/adr/           architecture decision records
```

An environment is one `terragrunt.stack.hcl` that instantiates catalog units with per-environment
`values` — so staging and prod share the same units and differ only by data. Adding an environment
touches no module code ([how](docs/adding-an-environment.md)); adding a module is two files
([how](docs/adding-a-module.md)).

## Quickstart

Prerequisites: [`mise`](https://mise.jdx.dev) (or install the pinned tools by hand — see
`mise.toml`). Then:

```bash
mise install                                   # opentofu, terragrunt, tflint, trivy, terraform-docs

# 1. Fill in the values you must own (account IDs, region, domain, deploy role):
for a in management staging prod; do
  cp live/$a/account.hcl.example live/$a/account.hcl
done
$EDITOR live/*/account.hcl                      # set account_id (and deploy_role_arn for real runs)

# 2. Validate everything offline — no AWS credentials needed:
make validate                                   # management + prod stacks

# 3. Plan against real AWS (needs credentials / the deploy role):
make plan ENV=prod
```

Bootstrapping a brand-new account starts with the `state-backend` unit — see
[modules/state-backend](modules/state-backend/README.md).

## Design decisions

The non-obvious choices are written up as ADRs:

- [OpenTofu as default, Terraform as drop-in](docs/adr/0001-opentofu-over-terraform.md)
- [Multi-account vs. single-account](docs/adr/0002-multi-account-vs-single-account.md)
- [Terragrunt Stacks vs. flat units](docs/adr/0003-terragrunt-stacks-over-flat-units.md)
- [Modules in-repo vs. separate repo](docs/adr/0004-modules-in-repo-vs-separate-repo.md)
- [S3 native locking vs. DynamoDB](docs/adr/0005-s3-native-locking-over-dynamodb.md)
- [EKS managed node groups only](docs/adr/0006-eks-managed-node-groups.md)
- [Tagging via provider default_tags](docs/adr/0007-tagging-and-default-tags.md)

## Conventions

- **No long-lived AWS keys.** CI authenticates with GitHub OIDC; workloads use IRSA.
- **Secrets never in code.** DB credentials are RDS-managed in Secrets Manager; Datadog keys come
  from the environment.
- **Every module** passes `tofu validate`, `tflint`, and `trivy config`, ships a `terraform-docs`
  README and a multi-platform lockfile, and pins providers with `~>`.
- **State** is per-account S3 with native locking and a customer-managed KMS key.

## License

[Apache 2.0](LICENSE).
