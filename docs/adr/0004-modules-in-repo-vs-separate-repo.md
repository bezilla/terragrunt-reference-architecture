# 4. Modules in-repo, referenced by repo root

Status: Accepted

## Context
Reusable modules can live in a separate versioned repo (referenced by `?ref=vX.Y.Z`) or alongside
the live configuration. Ad-hoc mixes of in-repo and git-referenced modules, often unpinned and with
stale paths, lead to version skew and broken references.

## Decision
Keep modules in `modules/` in this repo and reference them from catalog units with
`source = "${get_repo_root()}//modules/<name>"`. Wrap external community modules only where
reimplementation would be strictly worse — currently just `vpc` (terraform-aws-modules/vpc), pinned
with `~>`.

## Consequences
- One clone contains everything; a reviewer reads modules and their usage together.
- No cross-repo version skew, and no unpinned self-references.
- Tradeoff: modules cannot be independently versioned/released for external consumers. For a
  reference repo that is the right call; a platform team serving many app repos would
  split `modules/` into its own repo and pin tags. The `get_repo_root()` references are the only
  thing that would change.
