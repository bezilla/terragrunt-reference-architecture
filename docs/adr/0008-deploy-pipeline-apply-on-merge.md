# 8. Deploy pipeline: apply on merge, gated by environments

Status: Accepted

## Context
Changes need a path to production that is auditable and hard to fumble. Two shapes are common:
apply automatically when a PR merges to `main` (gated by a GitHub Environment with required
reviewers), or keep apply manual via `workflow_dispatch` and promote each environment by hand.

## Decision
Apply on merge to `main`, one environment at a time (management → staging → prod), each behind a
GitHub Environment. Production's environment carries a required reviewer, so a human still approves
the prod apply; the `apply` concurrency group prevents overlapping runs. Plans run on the PR, so
what merges has already been seen.

## Consequences
- The merge is the decision. Review happens on the PR (plan + policy + infracost comment) and at
  the prod environment gate, not in a separate promotion step.
- A consumer must create the three environments and set the reviewers; until then applies skip
  cleanly (no role variable).
- **Alternative considered — `workflow_dispatch` promotion:** keep apply fully manual and trigger
  each environment deliberately. It is the more conservative choice — nothing reaches prod without
  an explicit human action per run — and is the better fit for teams that want a hard separation
  between "merged" and "deployed"; merge-gated-by-environment was chosen here because the
  environment reviewer already provides that human gate while keeping the common path (merge →
  deploy) automatic and low-ceremony.
