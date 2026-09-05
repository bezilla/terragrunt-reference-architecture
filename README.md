# Terragrunt + OpenTofu Reference Architecture

[![validate](https://github.com/bezilla/terragrunt-reference-architecture/actions/workflows/validate.yml/badge.svg)](https://github.com/bezilla/terragrunt-reference-architecture/actions/workflows/validate.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![OpenTofu 1.12](https://img.shields.io/badge/OpenTofu-1.12-purple)
![Terragrunt 1.1](https://img.shields.io/badge/Terragrunt-1.1-orange)

A production-shaped AWS platform — EKS, Aurora, a CloudFront/WAF edge, Datadog monitoring, and
keyless CI — built as reusable OpenTofu modules and Terragrunt stacks, isolated across
management/staging/prod accounts. It is meant to be read as much as run: the non-obvious choices
are written down as ADRs, and everything is sanitized to placeholder values so you can clone it,
fill in a handful of inputs, and `plan` it. Aimed at platform engineers evaluating a Terragrunt
layout, and at anyone who wants a worked example rather than a tutorial.

## Architecture

![AWS topology: a management account holding a state backend, a GitHub OIDC deploy role and an IAM account baseline, and across a labelled account boundary a workload account running a VPC with EKS, its node group, add-ons, namespaces and the OpenTelemetry collector layer, alongside Aurora, Redis and Datadog monitors, plus an edge tier of Route53, ACM and CloudFront where the ACM certificate and CloudFront distribution exist only in prod](docs/images/aws-architecture.svg)

*Three accounts, one stack file each. The management account holds state and identity and runs no
workloads; the workload accounts share a shape but not a size, and the edge tier exists only in prod.*

Traffic resolves via Route53 → CloudFront (WAFv2, ACM cert in us-east-1) → EKS workloads. Pods
reach Aurora and Redis privately inside the VPC. State lives per-account in S3 with native locking.
Full write-up: [docs/architecture.md](docs/architecture.md).

### What each stack provisions

| Stack | Provisions | Rough monthly cost¹ |
|---|---|---|
| **management** | State bucket + KMS, GitHub OIDC provider, IAM users/groups/IRSA baseline | ~$5 |
| **staging** | VPC (1 NAT), EKS + spot nodes, Aurora (1× t4g.medium), Redis (t4g.small), Route53, Datadog monitors | ~$300 |
| **prod** | VPC (NAT/AZ), EKS + on-demand nodes, Aurora (2× r6g.large), Redis (r7g.large), CloudFront+WAF, ACM, Route53, monitors | ~$1,500 |

¹ Approximate, us-west-2 on-demand list prices, excluding data transfer and request charges. These
are hand estimates; the `plan` workflow posts a precise [Infracost](https://www.infracost.io) diff
on every PR once `INFRACOST_API_KEY` is set.

## Quickstart

Prerequisites: [`mise`](https://mise.jdx.dev) (installs the pinned OpenTofu/Terragrunt/tflint/etc.),
`git`, and AWS credentials for the account you're deploying into.

```bash
git clone https://github.com/bezilla/terragrunt-reference-architecture
cd terragrunt-reference-architecture
mise install                                    # pinned toolchain

# 1. Fill in the values you own (see "Required inputs"):
for a in management staging prod; do
  cp live/$a/account.hcl.example live/$a/account.hcl
done
$EDITOR live/*/account.hcl                       # set account_id, deploy_role_arn

# 2. Validate everything offline — no AWS credentials needed:
make validate

# 3. Bootstrap remote state. ONCE PER ACCOUNT, and it is its own operation.
#
#    live/root.hcl derives the backend bucket per account (tfstate-<account-id>-<region>), so
#    management, staging and prod each need their own. Every stack therefore carries a
#    state-backend unit, and it must be applied ON ITS OWN first: the other units in the stack
#    include the root config, so a single `run --all` on a fresh account races them against the
#    creation of the bucket they are trying to initialise a backend in.
#
#    The state-backend unit keeps LOCAL state permanently and by design — it cannot live in the
#    bucket it creates. See modules/state-backend/README.md, including how to recover it by import
#    if the local file is lost.
aws sso login                                    # or however you get credentials
cd live/management/us-west-2/global
terragrunt stack generate
(cd .terragrunt-stack/state-backend && terragrunt apply)   # bucket + KMS key, on local state
terragrunt run --all apply                                  # everything else, into that bucket
cd -

# 4. Deploy a stack (management is already applied above). Same two-step shape: bootstrap
#    that account's state bucket on its own, then the rest of the stack.
cd live/staging/us-west-2/staging
terragrunt stack generate
(cd .terragrunt-stack/state-backend && terragrunt apply)   # once per account, local state
terragrunt run --all plan                                   # review
terragrunt run --all apply
#    Then repeat for prod. Order: management → staging → prod.
```

CI does steps 3–4 for you via the `apply` workflow once you wire up OIDC (see [CI/CD](#cicd)).

## Required inputs

Everything else has a safe default. These do not:

| Input | Where | How to know it's right |
|---|---|---|
| `account_id` | `live/<account>/account.hcl` | 12-digit AWS account ID per environment; `aws sts get-caller-identity` |
| `deploy_role_arn` | `live/<account>/account.hcl` | ARN of the role Terragrunt assumes; leave empty to use ambient creds |
| GitHub org / repo | `catalog/units/iam-github-oidc` | your `owner/repo`, for the OIDC deploy-role trust `sub` claim |
| DNS zone | stack `values` (`route53-zone`, `acm-certificate`) | a domain you control in the account (Route53 must be authoritative) |
| Datadog keys | `DD_API_KEY` / `DD_APP_KEY` env vars | from Datadog; never committed — read by the datadog-monitors unit |
| `AWS_PLAN_ROLE_ARN` / `AWS_APPLY_ROLE_ARN` | repo Actions **variables** | ARNs from the `iam-github-oidc` module output; enables the CI pipeline |

## Repository layout

| Path | What's in it |
|---|---|
| `modules/` | 16 reusable OpenTofu modules (each with tests, a README, and a lockfile) |
| `catalog/units/` | Terragrunt unit definitions that source the modules |
| `live/` | `root.hcl` + per-account `account.hcl`/`region.hcl`/`env.hcl` + environment stacks |
| `policy/` | OPA/conftest policies (tags, ingress, encryption, IMDSv2) + tests |
| `docs/` | architecture, ADRs, and how-to guides |
| `.github/workflows/` | validate (PR), plan (PR), apply (merge), drift (weekly) |

## Design decisions

Each links to its ADR:

- [OpenTofu default, Terraform drop-in](docs/adr/0001-opentofu-over-terraform.md) — avoid the BSL, stay compatible.
- [Multi-account isolation](docs/adr/0002-multi-account-vs-single-account.md) — account boundaries over VPC-only separation.
- [Terragrunt Stacks](docs/adr/0003-terragrunt-stacks-over-flat-units.md) — one stack file per environment, not copied unit trees.
- [Modules in-repo](docs/adr/0004-modules-in-repo-vs-separate-repo.md) — one clone, referenced by repo root.
- [S3 native locking](docs/adr/0005-s3-native-locking-over-dynamodb.md) — no DynamoDB lock table.
- [Managed node groups](docs/adr/0006-eks-managed-node-groups.md) — one worker strategy, not three.
- [Tagging via default_tags](docs/adr/0007-tagging-and-default-tags.md) — baseline tags once, in the provider.
- [Deploy pipeline](docs/adr/0008-deploy-pipeline-apply-on-merge.md) — apply on merge, gated by a prod environment reviewer.
- [Observability & the OTel collector](docs/adr/0009-otel-collector-and-optional-kafka-bus.md) — the collector as the cloud-portability seam; Kafka only above a stated bar.
- [Kubernetes version & upgrade policy](docs/adr/0010-kubernetes-version-and-upgrade-policy.md) — pin the oldest minor still in standard support; control plane → add-ons → nodes.

Monitoring is shown mid-migration on purpose: the incumbent `datadog-monitors` and the portable OpenTelemetry collector layer run side by side, the export seam letting them coexist rather than forcing a big-bang cutover.
The retirement criteria for the Datadog unit — and what stays vendor-native on purpose — are in [ADR-0009](docs/adr/0009-otel-collector-and-optional-kafka-bus.md#coexistence-with-the-incumbent-monitoring-amendment).

How telemetry actually flows — the three signal pipelines, the export seam, the recording rules, and the multi-window SLO burn-rate alerting — is written up in [OBSERVABILITY.md](OBSERVABILITY.md), which opens with a [diagram of the module's scope](docs/images/observability-architecture.svg): where the application boundary falls, which exporters are swappable, and which route is optional.

## Reference boundary

What this is, stated plainly, because several things it is *not* look like omissions otherwise.

**It is an application-platform reference.** VPC, EKS, data stores, edge, observability and the
pipeline that plans and applies them, expressed as reusable modules and per-account stacks.

**It is not a landing zone.** There is no AWS Organizations setup, no Control Tower, no SCPs, no
account vending, no centralised logging or GuardDuty/Security Hub baseline. It assumes the accounts
already exist and that you own credentials for them. If you are looking for the layer that *creates*
accounts and governs them, that is a different repository and a much larger one — graded as a landing
zone, this will always look incomplete, because it is not attempting that job.

**It is validated, not apply-tested.** Every push runs `fmt`, offline `validate` across all stacks,
module unit tests (`tofu test`) and policy unit tests (`conftest verify`). Nothing in CI has ever
applied this to a live AWS account: there is no account behind it. The plan and apply workflows are
real and wired, and they are inert until you supply `AWS_PLAN_ROLE_ARN` / `AWS_APPLY_ROLE_ARN`. Treat
the resource configurations as reviewed-and-validated, not as battle-tested.

**The deploy role is deliberately under-powered.** `catalog/units/iam-github-oidc` attaches
`ReadOnlyAccess`, which is enough to plan and not enough to apply. Scoping a real per-account
plan/apply role — least-privilege write access to exactly the resources these stacks manage, brokered
per environment — is a genuine piece of work this repository documents rather than performs. Widening
that policy is a decision you should make explicitly, with your own resource scope, rather than
inherit from an example.

### What this deliberately does not do

Scope is a choice; these omissions are intentional, not unfinished:

- **No multi-region.** One region per account. Aurora Global Database is available behind a flag,
  but active-active multi-region is a large operational commitment this reference doesn't pretend to.
- **No service mesh.** Namespace RBAC and security groups, not Istio/Linkerd. A mesh earns its
  complexity at a scale a reference repo can't honestly demonstrate.
- **One Kubernetes compute model.** Managed node groups only — no self-managed ASGs, no Karpenter,
  no Fargate mix. When each of those is worth it is in [ADR-0006](docs/adr/0006-eks-managed-node-groups.md).
- **One CDN, and monitoring shown mid-migration.** CloudFront, not a multi-vendor edge; and a single
  incumbent monitoring vendor (Datadog) running alongside the portable OpenTelemetry layer, not an
  abstraction over observability backends (see ADR-0009).

## Day 2

- [Adding an environment](docs/adding-an-environment.md)
- [Adding a module](docs/adding-a-module.md)

### Tearing it down

Destroy in reverse dependency order, and never destroy `management` before the workload accounts
(it holds their state):

```bash
for stack in prod/us-west-2/prod staging/us-west-2/staging; do
  cd live/$stack && terragrunt run --all destroy && cd -
done
# Aurora has deletion_protection and skip_final_snapshot=false: disable protection and take/accept
# the final snapshot first, or the destroy will refuse. Then, last:
cd live/management/us-west-2/global && terragrunt run --all destroy
# The state bucket has versioning + a KMS key; empty and delete it by hand if you want it gone.
```

## CI/CD

Four workflows, all of which skip cleanly (with a message) when their AWS role variables are unset:

- **validate** (PR) — `tofu fmt`, `terragrunt hcl fmt`, tflint, trivy, terraform-docs drift,
  gitleaks, offline `run --all validate`, and `make test` (module + policy tests).
- **plan** (PR) — detects changed stacks, assumes `AWS_PLAN_ROLE_ARN` via OIDC, plans each, checks
  the plan against the conftest policies, and comments the plan + Infracost diff.
- **apply** (merge to `main`) — applies management → staging → prod, each behind a GitHub
  Environment. **You must create these Environments** and put required reviewers on `prod`.
- **drift** (weekly) — plans every stack and opens an issue if one has drifted.

To adopt: run the `iam-github-oidc` module, set the two role ARNs as repository **Variables**, and
create the three Environments. The exact IAM trust policy is documented at the top of
[`plan.yml`](.github/workflows/plan.yml). No long-lived AWS keys are used anywhere.

## Related

- [capsize](https://github.com/bezilla/capsize) — a read-only Kubernetes CLI that scores cost waste and blast radius together, for the kind of EKS clusters this architecture provisions.

## License

[Apache 2.0](LICENSE).
