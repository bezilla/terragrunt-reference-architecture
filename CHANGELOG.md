# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- The `state-backend` bootstrap moved out of the generated stacks into per-account unit directories
  at `live/<account>/<region>/bootstrap/state-backend`, with an explicit local backend pinned
  outside `.terragrunt-stack`. No `terragrunt run --all` — plan, apply, destroy or the weekly drift
  job — can reach it any more, and a repeat `run --all apply` on a fresh checkout no longer tries to
  recreate an existing state bucket. Added `make bootstrap` / `make bootstrap-plan`, and ADR-0011.

## [0.1.0]

### Added
- Fifteen reusable OpenTofu modules covering networking, EKS, data (Aurora/Redis), edge
  (CloudFront/WAF, ACM, Route53), observability (Datadog monitors), and IAM (GitHub OIDC, account
  baseline with IRSA), plus a state-backend bootstrap.
- Terragrunt Stacks layout: a single `root.hcl`, a `catalog/` of reusable units, and
  management/staging/prod environment stacks.
- Native `tofu test` on every module and an OPA/conftest policy layer (mandatory tags, no open
  ingress, encryption at rest, IMDSv2).
- CI: offline validation, static analysis (tflint, trivy, terraform-docs drift, gitleaks), and the
  deploy-pipeline skeletons.
- Docs: architecture overview, seven ADRs, and how-to guides for adding environments and modules.

[Unreleased]: https://github.com/bezilla/terragrunt-reference-architecture/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bezilla/terragrunt-reference-architecture/releases/tag/v0.1.0
