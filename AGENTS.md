# Agent instructions

Rules for anyone working in this repository, automated or not. They exist because the
enforcement described at the bottom is local-only and does not travel with a clone.

Every forbidden term on this page is written with a bracket inside it — `c[l]aude`,
`anthrop[i]c`, `co-auth[o]red` — so that this file does not itself match the
case-insensitive scan that enforces the rules below. Leave the brackets in place; a
"tidy-up" that removes them will start failing the scan.

## Commit identity

Author and committer must both be:

```
Paul Bezilla <bezilla@protonmail.com>
```

Both fields, on every commit. Never substitute another identity, and never infer one
from the environment or the host account.

## No attribution

No assistant, AI, model, vendor or tool attribution anywhere: commit messages, code
comments, documentation, examples, generated assets, filenames, branches, tags,
releases, or configuration. No trailers of any kind, including `Co-Auth[o]red-By` and
session or provenance links. Do not add third parties as authors, co-authors,
reviewers or collaborators unless Paul names them.

Attribution-free does not license inaccuracy: never fabricate test results, approvals,
review, or actions that did not happen.

## Merging

Never `gh pr merge`, in any mode, and never `--squash`. A server-side merge or squash
rewrites the *committer* to the GitHub account — `GitHub <noreply@github.com>` — and no
repository setting prevents it. That breaks the identity rule above, and it cannot be
corrected afterwards without rewriting history.

Merge locally and push `main` directly, so every push passes through the hook below.

## Enforcement

`.git/hooks/pre-push` refuses a push that carries a non-canonical author or committer,
attribution in a commit message, attribution anywhere in the working tree, or a
gitleaks match.

That hook lives in `.git/`, so it is **local and uncommitted**. It does not travel with
a clone, and there is no CI job checking commit identity or attribution — nothing on
the server enforces any of this. A fresh clone gets this file and no hook, which is why
these rules are written down rather than left to the hook to catch.
