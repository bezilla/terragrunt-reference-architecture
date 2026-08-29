# 7. Tagging via provider default_tags

Status: Accepted

## Context
Threading a hand-rolled `tags` map through every module and resource is a common source of tag
inconsistency. The AWS provider's `default_tags` applies a tag set to every taggable resource
created by that provider.

## Decision
Apply baseline tags (`Namespace`, `Environment`, `ManagedBy`) once, in the generated provider in
`live/root.hcl`, via `default_tags`. Modules keep a `tags` variable only for resource-specific
*additions*, merged over the defaults.

## Consequences
- Every resource in an environment carries consistent baseline tags without per-module effort.
- Modules stay focused; `tags` is for the exceptions, not the baseline.
- `default_tags` can produce perpetual-diff noise on a few resource types that also set tags inline
  — none are used here, but it's the known caveat if the pattern is extended.
