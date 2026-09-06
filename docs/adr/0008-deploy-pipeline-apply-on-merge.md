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
- **The prod approval prompt fires only on infrastructure changes, and that is the intended
  behaviour.** `precheck` runs ungated and first: a push touching only `.github/` decides
  `deploy=false`, so no environment is entered, no reviewer is prompted, and an ungated job still
  records a no-op deployment for all three environments. A push touching infrastructure decides
  `deploy=true`, prod waits on its required reviewer, and with no `AWS_APPLY_ROLE_ARN` configured
  the approved deployment is relabelled `No-op: approved, but no AWS role is configured so nothing
  was applied`. Being asked to approve a prod apply on an infrastructure change is the guardrail
  doing its job, so it stays as it is. Two alternatives were rejected: having `precheck` skip the
  gated path when no role is configured would remove the prompt but also the deployment record,
  leaving the environment panel blank on exactly the pushes that propose to change infrastructure;
  dropping the required reviewer from prod would remove the human gate this ADR exists to
  establish.
- **Alternative considered — `workflow_dispatch` promotion:** keep apply fully manual and trigger
  each environment deliberately. It is the more conservative choice — nothing reaches prod without
  an explicit human action per run — and is the better fit for teams that want a hard separation
  between "merged" and "deployed"; merge-gated-by-environment was chosen here because the
  environment reviewer already provides that human gate while keeping the common path (merge →
  deploy) automatic and low-ceremony.
