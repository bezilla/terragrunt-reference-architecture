# Agent instructions

Rules for anyone working in this repository, automated or not.

## Commit identity

Author and committer must both be:

```
Paul Bezilla <bezilla@protonmail.com>
```

Both fields, on every commit. Never substitute another identity, and never infer one
from the environment or the host account. Annotated tags carry an identity too: the
tagger must be the same.

## Commit trailers are allowlisted

Only three trailer keys may appear in a commit's trailer block, or in an annotated
tag's annotation body. Every other key is refused:

| trailer | rule |
|---|---|
| `Signed-off-by` | must be exactly `Paul Bezilla <bezilla@protonmail.com>` |
| `Verified` | free text |
| `Measured` | free text |

This replaced a scan that searched commit messages for a list of vendor and tool
names. Measured before removing it: across the full history of all six repositories
in this family, 207 commits, that scan matched nothing.

A denylist catches only what somebody thought to write down. It is stale the day a
tool ships using a word nobody predicted, and the set of tools that do not exist yet
cannot be enumerated. The allowlist inverts it: any tool that stamps provenance onto
a commit does so through a trailer, so an unlisted key is refused whether or not this
repository has heard of what wrote it.

That is the whole rule. No assistant, model, vendor or tool attribution belongs in
commit messages, code comments, documentation, examples, filenames, branches, tags or
configuration either — but the trailer allowlist is the part that is mechanically
enforced, and it is enforced on the key rather than on a list of names.

Do not add third parties as authors, co-authors, reviewers or collaborators unless
Paul names them. Attribution-free does not license inaccuracy: never fabricate test
results, approvals, review, or actions that did not happen.

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

The gate reads trailers with `git interpret-trailers --parse` — git's own definition,
and the definition the tools that stamp provenance use. A `^Key:` regex would be
simpler and would reject this repository's own commit prose: **18 distinct
`Key: Value` shapes appear in these messages across 36 commits and not one of them is
a trailer** — `docs:`, `chore:`, `ci:`, `test:`, `cannot:`, `does:`, `it:`, `once:`,
`zone:`, `policy:`, `telemetry:`, `diagram:` and more.

If a push is refused for a trailer you thought was prose, check whether it ended up in
the final paragraph. A new evidence word — `Tested:`, `Confirmed:` — needs adding to
the allowlist before it can land there.

## Merging

Never `gh pr merge`, in any mode, and never `--squash`. A server-side merge or squash
rewrites the *committer* to the GitHub account — `GitHub <noreply@github.com>` — and no
repository setting prevents it. That breaks the identity rule above, and it cannot be
corrected afterwards without rewriting history.

Merge locally and push `main` directly.

## Enforcement

The `identity` job in [`.github/workflows/validate.yml`](.github/workflows/validate.yml)
checks every commit in the pushed range and every annotated tag: canonical author and
committer, and the trailer allowlist above. It checks out at `fetch-depth: 0`, because
the default shallow clone would leave the base of the range absent locally and the walk
would silently check nothing.

Its scope is deliberately narrow. A first push to a branch reports an all-zero base and
a force push reports a base that is no longer an ancestor; both fall back to every
commit reachable from the head, which checks more than the range and never less. Tags
are enumerated from `refs/tags` directly, since they are not part of a push range.

**`refs/pull/N/head` is out of scope and stays that way.** GitHub keeps a permanent
copy of every pull request head there — this repository has eight — and several carry a
dependency bot's identity. That identity exists on no branch and no tag here. A gate
that flags a commit nobody authored and nobody can remove is a gate that cannot be
satisfied, and a gate that cannot be satisfied gets switched off.

**There is now a committed hook too.** `.githooks/pre-push` enforces the same rule
locally, before a commit can become permanent, and `make init` installs it by setting
`core.hooksPath=.githooks`. It carries the *same* `check_trailers` function as the CI
job — `.githooks/selftest.sh` hashes it out of both files and fails if they ever differ,
so the local gate and the server gate cannot drift apart silently.

Run `make init` in every clone. `core.hooksPath` is per-clone configuration and does not
travel with a clone, which is exactly why the CI job stays: it is the copy nobody can
forget to install.

**`make init` makes git ignore `.git/hooks/` entirely.** That is how `core.hooksPath`
works, and it is worth knowing because this repository previously kept hand-written
hooks there. `.githooks/pre-commit` carries forward the one part still worth having —
the `gitleaks` scan against the gitignored `.gitleaks.local.toml`. It also means
`pre-commit install` no longer takes effect at `.git/hooks/`; run `pre-commit run` (or
`make scan`) explicitly instead.

## History

The gate changed; **history was not rewritten.** No force push, no retag, nothing
dropped. Every commit and the one tag that existed before the allowlist replaced the
name scan exist unchanged after it. Only the rule applied to new pushes is different.
