# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- The `identity` job now allowlists commit trailers instead of matching commit messages
  against a name-based denylist. Only `Signed-off-by` carrying exactly
  `Paul Bezilla <bezilla@protonmail.com>`, `Verified` and `Measured` may appear; every
  other key is refused. A denylist catches only what somebody thought to write
  down, and cannot be completed. Trailers are read with
  `git interpret-trailers --parse`, git's own definition, because a `^Key:` regex would
  reject this repository's own commit prose: 20 distinct `Key: Value` shapes appear
  across its 73 commits (`docs:`, `chore:`, `ci:`, `test:`, `once:`, `zone:`, `cannot:`
  and more) and not one of them is a trailer.
- The job now also checks annotated tags — tagger identity and annotation body against
  the same allowlist. `v0.1.0` passes as it stands; nothing inspected it before.
- Scope is unchanged: the pushed range with its all-zero-base and non-ancestor-base
  fallbacks, plus `refs/tags`. `refs/pull/N/head` stays out of reach — eight of them
  exist here and several carry a dependency bot's identity that appears on no branch
  and no tag. Both fallback paths were exercised directly for the first time: each
  expands to all 66 reachable commits, and each still refuses a bad commit.
- The commit identity and trailer policy documentation was consolidated into
  CONTRIBUTING.md and reworded. The separate policy document was removed; its content
  lives in CONTRIBUTING.md unchanged in substance. No gate, workflow or hook changed
  behaviour.

**History was not rewritten.** No force push, no retag. Both the old and the new job
were run over all 66 commits reachable from `5bb36e9` first: old accepted 66 / rejected
0, new accepted 66 / rejected 0, disagreements 0.
- The `state-backend` bootstrap moved out of the generated stacks into per-account unit directories
  at `live/<account>/<region>/bootstrap/state-backend`, with an explicit local backend pinned
  outside `.terragrunt-stack`. No `terragrunt run --all` — plan, apply, destroy or the weekly drift
  job — can reach it any more, and a repeat `run --all apply` on a fresh checkout no longer tries to
  recreate an existing state bucket. Added `make bootstrap` / `make bootstrap-plan`, and ADR-0011.

### Fixed
- Provider-lock churn in generated units. `live/root.hcl` gave every unit an AWS provider, which in
  the three units whose modules never declare `hashicorp/aws` (`datadog-monitors`, `k8s-namespace`,
  `observability`) was an unconstrained provider requirement: a clean-clone `make validate-all`
  resolved aws 6.63.0 against modules locked at 6.62.0 and rewrote the generated lockfiles. The
  provider is now generated per unit, those three opt out, and the Kubernetes units authenticate
  with the `exec` plugin instead of an `aws_eks_cluster_auth` data source. Added `make lock` and a
  CI assertion that validation resolves nothing unconstrained. See ADR-0012.
- `apply.yml` labelled staging and prod deployments as successful no-ops based on the management
  job's result alone, which could paint a green status over a failed or skipped environment. Each
  environment is now labelled from its own job result.

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
