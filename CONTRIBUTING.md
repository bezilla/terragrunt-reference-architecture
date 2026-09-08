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

### Identity

Author and committer must both be:

```
Paul Bezilla <bezilla@protonmail.com>
```

Both fields, on every commit. Never substitute another identity, and never infer one
from the environment or the host account. Annotated tags carry an identity too: the
tagger must be the same.

### Trailers are allowlisted

Only three trailer keys may appear in a commit's trailer block, or in an annotated
tag's annotation body. Every other key is refused:

| trailer | rule |
|---|---|
| `Signed-off-by` | must be exactly `Paul Bezilla <bezilla@protonmail.com>` |
| `Verified` | free text |
| `Measured` | free text |

This repository requires one canonical commit identity and a small, fixed vocabulary
of evidence trailers. Any trailer key outside that vocabulary is refused. An allowlist
is used rather than a denylist because a denylist can only refuse what someone thought
to write down, and the set of keys that do not exist yet cannot be enumerated.

### The trailer rule has one sharp edge

Whether a `Key: Value` line is a trailer depends on **which paragraph it lands in**.
git parses only the last paragraph, and only when the whole paragraph parses as
trailers:

```
Pin the provider version             Pin the provider version

Verified: plan is clean.             Verified: plan is clean.

And a closing paragraph.             ← nothing after it
```

The left-hand message ends in prose, so `Verified:` there is ordinary text the gate
never inspects. The right-hand one ends with that line, so it **is** a trailer and its
key must be allowlisted. Same words, two outcomes, decided by what comes after.

The gate reads trailers with `git interpret-trailers --parse` — git's own definition.
A `^Key:` regex would be simpler and would reject this repository's own commit prose:
**20 distinct `Key: Value` shapes appear in these messages across 73 commits and not
one of them is a trailer** — `docs:`, `chore:`, `ci:`, `test:`, `cannot:`, `does:`,
`it:`, `once:`, `zone:`, `policy:`, `telemetry:`, `diagram:` and more.

If a push is refused for a trailer you thought was prose, check whether it ended up in
the final paragraph. A new evidence word — `Tested:`, `Confirmed:` — needs adding to
the allowlist before it can land there.

### Merging

Never `gh pr merge`, in any mode, and never `--squash`. A server-side merge or squash
rewrites the *committer* to the GitHub account — `GitHub <noreply@github.com>` — and no
repository setting prevents it. That breaks the identity rule above, and it cannot be
corrected afterwards without rewriting history.

Merge locally and push `main` directly.

### The gate runs in two places

```bash
make init       # step 1 in any clone: sets core.hooksPath=.githooks
make test-hook  # prove the gate rejects and accepts what it claims
make identity   # run the gate over all of this repository's history
```

`.githooks/pre-push` catches a bad commit *before* it becomes permanent; the `identity`
job in `.github/workflows/validate.yml` runs whether or not anyone remembered
`make init`. Identity is baked into the commit hash and `refs/pull/N/head` is
permanent — there are eight here — so catching it locally is not a convenience.

The `identity` job checks out at `fetch-depth: 0`, because the default shallow clone
would leave the base of the range absent locally and the walk would silently check
nothing.

Its scope is deliberately narrow. A first push to a branch reports an all-zero base and
a force push reports a base that is no longer an ancestor; both fall back to every
commit reachable from the head, which checks more than the range and never less. Tags
are enumerated from `refs/tags` directly, since they are not part of a push range.

**`refs/pull/N/head` is out of scope and stays that way.** GitHub keeps a permanent
copy of every pull request head there — this repository has eight — and several carry a
dependency bot's identity. That identity exists on no branch and no tag here. A gate
that flags a commit nobody authored and nobody can remove is a gate that cannot be
satisfied, and a gate that cannot be satisfied gets switched off.

Both copies carry the **same** `check_trailers` function. `.githooks/selftest.sh` hashes
it out of `.githooks/pre-push` and out of the workflow (dedenting the YAML block scalar
by its ten spaces first) and fails if they differ. Change the allowlist in one and the
test tells you about the other.

Run `make init` in every clone. `core.hooksPath` is per-clone configuration and does not
travel with a clone, which is exactly why the CI job stays: it is the copy nobody can
forget to install.

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
A hand-written `commit-msg` there matched the whole message against a name list; nothing
replaces it, and nothing should. The trailer allowlist in `.githooks/pre-push` works on
the *key*, so it refuses an unlisted key whether or not the gate has heard of it, which
is stronger than a name list that goes stale the day something new ships. Its scope is
the trailer block and nothing else: it does not read the message body, and nothing greps
the working tree. That is the reduction, taken knowingly. The tree-wide grep is gone for
that reason and one more: it walked `.terraform/`, which is exactly what made a clean
tree unpushable after a validate run. The `gitleaks` scan above is the piece that
was worth carrying forward, and it was carried forward.

Conventional-commit messages (`feat(modules): ...`, `fix(live): ...`, `docs: ...`). One logical
change per commit.

## Sanitization
This repo contains only placeholder values. Do not add real account IDs, domains, hostnames,
credentials, or personal names in code, comments, commit messages, or docs. `make scan` and CI
enforce this.
