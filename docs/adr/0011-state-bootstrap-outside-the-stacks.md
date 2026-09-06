# 11. State bootstrap lives outside the generated stacks

Status: Accepted

## Context
Every account's state lives in an S3 bucket named `tfstate-<account-id>-<region>`, created by the
`state-backend` module. That module cannot keep its state in the bucket it creates, so the unit
that instantiates it does not include `root.hcl` and generates no S3 backend at all — it runs on
local state (see [ADR-0005](0005-s3-native-locking-over-dynamodb.md) for the locking side of this).

That unit was originally a member of every `terragrunt.stack.hcl`, with a comment telling the
operator to apply it on its own before `run --all`. The instruction was correct and the arrangement
still did not hold, because a stack member's working directory is `.terragrunt-stack/`, which is
generated, gitignored, and deleted by `make clean`. Local state kept there survives exactly as long
as one checkout:

- `make clean` removes it.
- Every CI checkout starts without it.
- The next `run --all apply` therefore includes a `state-backend` unit with empty state, and tries
  to create a bucket and a KMS key that already exist.
- `run --all destroy` and the weekly drift job reach a bootstrap unit neither should ever manage.

The comment described a lifecycle the directory layout could not support.

## Decision
Move the bootstrap out of the generated tree. Each account gets a hand-written unit directory:

```
live/<account>/<region>/bootstrap/state-backend/terragrunt.hcl
```

alongside — not inside — that region's environment stacks. It is placed at the region level because
the bucket is named for the account *and* region, so it is one per account per region however many
environment stacks that account carries.

- No `terragrunt.stack.hcl` instantiates `state-backend`. Stack generation cannot produce it, and
  `terragrunt run --all` from a stack directory cannot descend into it, so no plan, apply, destroy
  or drift run touches it.
- The shared definition stays in `catalog/units/state-backend`; the bootstrap directories `include`
  it, so there is still one definition and the account/region config resolves from the hierarchy.
- The unit generates an explicit **local backend** pinned to its own directory via
  `get_terragrunt_dir()`. Without that, OpenTofu runs inside `.terragrunt-cache` and the state file
  would land in a cache directory — the same disappearing act, one level down.
- `root.hcl` is untouched, and the bootstrap unit still does not include it. The root backend
  therefore never becomes a chicken-and-egg dependency.
- Driven by `make bootstrap ACCOUNT=<account>`, and by nothing in CI.

## Where the state lives, and how it is recovered
`live/<account>/<region>/bootstrap/state-backend/terraform.tfstate`, on the machine that ran the
bootstrap. It is gitignored — it is state, and it names real infrastructure — and `make clean`
leaves it alone.

**This makes the bootstrap a once-per-account operation, not a repeatable one.** There is no shared
copy of that file. Run `make bootstrap` on a second machine, or after losing the file, and OpenTofu
sees empty state and tries to create a bucket that already exists. Recovery is by import, not by
re-running; the full import sequence is in
[modules/state-backend/README.md](../../modules/state-backend/README.md). Back the file up, or
accept the import as the recovery path — but do not treat the target as idempotent, because it
is not.

## Consequences
- `run --all apply` is now safe to repeat on a fresh checkout: nothing in the stack owns the bucket.
- The bootstrap is a visible, tracked directory rather than a step buried in a stack-file comment.
- Two operations exist per account instead of one, and the first is manual and human-gated. That is
  the honest shape: it is a once-ever action on the resource everything else depends on.
- CI never creates the bucket it stores its own state in. An account that was never bootstrapped
  fails at backend initialisation, which is the correct failure rather than a silent recreate.
- `make validate-all` validates the bootstrap units, so excluding them from every run path does not
  leave them as the one piece of configuration nothing ever checks.
- **Alternative considered — migrate the bootstrap state into the bucket it creates.** The usual
  advice, and reasonable: it removes the local file entirely. Rejected here because the migration is
  a hand step (`tofu init -migrate-state` against a backend block the unit does not generate) and it
  puts the record of the bucket inside the bucket, so a bucket-destroying accident takes the
  recovery path with it. Nothing prevents adopting it; do it consistently across accounts and update
  the quickstart to match.
