# Contributing

## Toolchain
`mise install` provisions the pinned versions (OpenTofu, Terragrunt, tflint, trivy,
terraform-docs). Versions are exact on purpose — see the note in `mise.toml`.

## Before you push
```bash
make fmt          # format HCL + tofu
make validate     # offline validate (no AWS credentials)
make lint         # tflint across modules
make scan         # gitleaks + trufflehog (needs .gitleaks.local.toml)
pre-commit install --hook-type pre-commit --hook-type pre-push   # once
pre-commit run --all-files
```

## Modules
Every module ships: typed/described variables, described outputs, a `terraform-docs` README, a
multi-platform lockfile, and a clean pass under `tofu validate` + `tflint` + `trivy config`. See
[docs/adding-a-module.md](docs/adding-a-module.md). Regenerate a README with `make docs`.

## Commits
Conventional-commit messages (`feat(modules): ...`, `fix(live): ...`, `docs: ...`). One logical
change per commit.

## Sanitization
This repo contains only placeholder values. Do not add real account IDs, domains, hostnames,
credentials, or personal names in code, comments, commit messages, or docs. `make scan` and CI
enforce this.
