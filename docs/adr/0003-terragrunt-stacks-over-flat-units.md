# 3. Terragrunt Stacks over flat per-environment units

Status: Accepted

## Context
The source system defined each environment as a directory tree of ~70 hand-copied
`terragrunt.hcl` units. Environments drifted (units present in one but not another), and a change
to a shared pattern meant editing dozens of files. Terragrunt Stacks (`terragrunt.stack.hcl`,
GA in Terragrunt 1.0+) let one stack file instantiate reusable *catalog units* with
per-environment `values`, and supersede the older `_envcommon` include pattern.

## Decision
Express each environment as a single `terragrunt.stack.hcl` that instantiates units from
`catalog/units/`. Do not use `_envcommon` (Stacks replace it; keeping both would be two ways to do
one thing).

## Consequences
- Environments differ by data (`values` in the stack file), not by copied directories. staging and
  prod share the same catalog units.
- A generation step: `terragrunt stack generate` materializes `.terragrunt-stack/` before
  plan/apply. This is wrapped by `make` and gitignored.
- Stacks are newer; `optional-dependency-outputs` (used for offline validation) is still an
  experiment. Tool versions are pinned in `mise.toml` for that reason (see the Makefile note).
- The "real" unit definitions live in `catalog/units/`, one indirection away from the environment
  directories. Mitigated by keeping the catalog small and heavily commented.
