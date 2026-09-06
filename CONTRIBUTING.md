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

### The gate runs in two places

```bash
make init       # step 1 in any clone: sets core.hooksPath=.githooks
make test-hook  # prove the gate rejects and accepts what it claims
make identity   # run the gate over all of this repository's history
```

`.githooks/pre-push` catches a bad commit *before* it becomes permanent; the `identity`
job in `validate.yml` runs whether or not anyone remembered `make init`. Identity is
baked into the commit hash and `refs/pull/N/head` is permanent — there are eight here —
so catching it locally is not a convenience.

Both copies carry the **same** `check_trailers` function. `.githooks/selftest.sh` hashes
it out of `.githooks/pre-push` and out of the workflow (dedenting the YAML block scalar
by its ten spaces first) and fails if they differ. Change the allowlist in one and the
test tells you about the other.

**`make init` makes git ignore `.git/hooks/` entirely** — that is what `core.hooksPath`
does. If you kept hand-written hooks there they stop running, and `pre-commit install`
no longer takes effect at that path. `.githooks/pre-commit` carries forward the piece
worth keeping: the `gitleaks` scan against the gitignored `.gitleaks.local.toml`. Run
`pre-commit run --all-files` or `make scan` explicitly for the rest.

One thing that will bite: that scan walks the **working tree**, and `make validate-all`
leaves vendored upstream modules under `.terraform/` whose example files carry a
real-looking AWS account id. If the hook fires right after a validate run, `make clean`
first.

The two checks that went quiet with `.git/hooks/` are deliberate losses, not casualties.
A hand-written `commit-msg` there scanned the whole message for vendor names; nothing
replaces it, and nothing should. The trailer allowlist in `.githooks/pre-push` catches
attribution by *key*, from any tool whether or not the gate has heard of it, which is
stronger than a name list that goes stale the day something new ships — but it reads the
trailer block and nothing else, so a vendor name in a message **body** now passes. That is
the reduction, taken knowingly. The tree-wide grep for the same names is gone for that
reason and one more: it matched nothing across the full history of every repository in
this family, and it walked `.terraform/`, which is exactly what made a clean tree
unpushable after a validate run. The `gitleaks` scan above is the piece that was worth
carrying forward, and it was carried forward. Every repository sharing this gate makes the
same trade; consistency across them is the property worth keeping.

Conventional-commit messages (`feat(modules): ...`, `fix(live): ...`, `docs: ...`). One logical
change per commit.

## Sanitization
This repo contains only placeholder values. Do not add real account IDs, domains, hostnames,
credentials, or personal names in code, comments, commit messages, or docs. `make scan` and CI
enforce this.
