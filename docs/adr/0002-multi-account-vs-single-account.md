# 2. Multi-account layout (management / staging / prod)

Status: Accepted

## Context
The production system this repo was derived from ran prod, staging, and sandbox as prefixes inside
a *single* AWS account, separated by VPC and resource naming. That is a common and inexpensive
starting point, but it shares an IAM trust boundary, service quotas, and blast radius across
environments, and it makes SCP-based guardrails ("non-prod may never touch prod") impossible to
express.

## Decision
Model three accounts — `management` (state backend, GitHub OIDC provider, org-wide IAM), `staging`,
and `prod` — each with its own `account.hcl`. Environment isolation is by account, not by prefix.

## Consequences
- Hard isolation: a compromised staging credential cannot reach prod state or resources.
- Guardrails become expressible with Organizations SCPs (not included here, but the structure
  invites them).
- More moving parts: three state buckets, cross-account role assumption for deploys. The
  `deploy_role_arn` in each `account.hcl` is where that plugs in.
- Honest tradeoff: single-account-with-VPC-separation is cheaper and simpler and is a legitimate
  place to start. This layout is what you graduate to when isolation matters more than simplicity.
