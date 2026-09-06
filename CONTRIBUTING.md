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

Author and committer must both be `Paul Bezilla <bezilla@protonmail.com>`, and only
three trailer keys are allowed on a commit or in an annotated tag's body:
`Signed-off-by` (carrying exactly that identity), `Verified` and `Measured` (both free
text). Every other key is refused. The full rule, and the one edge that will catch you
out — a `Key: Value` line is only a trailer if it lands in the **final** paragraph —
is in [AGENTS.md](AGENTS.md).

The `identity` job in `.github/workflows/validate.yml` enforces it over the pushed
range and every annotated tag.

### There is no committed hook here, and there probably should be

The other five repositories in this family commit a `.githooks/pre-push` and point
`core.hooksPath` at it via `make init`, so the rule travels with a clone and a bad
commit is caught *before* it becomes permanent. This repository is the exception: its
only gate is the CI job, which by definition runs after the commit already exists on a
remote. Identity is baked into the commit hash and `refs/pull/N/head` is permanent, so
"after" is sometimes too late to fix cleanly.

Adding one is an open recommendation, not a decision taken. It would need the same
`check_trailers` logic the CI job carries, kept in step with it, and `make init` wired
to set `core.hooksPath` — the shape the sibling repositories already use.

Conventional-commit messages (`feat(modules): ...`, `fix(live): ...`, `docs: ...`). One logical
change per commit.

## Sanitization
This repo contains only placeholder values. Do not add real account IDs, domains, hostnames,
credentials, or personal names in code, comments, commit messages, or docs. `make scan` and CI
enforce this.
