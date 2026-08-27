# 6. EKS managed node groups (only)

Status: Accepted

## Context
The source system carried three worker generations simultaneously: self-managed ASG workers
(bootstrap templates + `cloudposse/eks-workers`), EKS managed node groups, and Spot.io Ocean for
spot bin-packing. Three ways to run nodes is two too many for a reference.

## Decision
Provide one node module: `eks-managed-node-group`, using EKS managed node groups with a launch
template (IMDSv2 enforced, encrypted gp3 volumes). Support spot via `capacity_type = "SPOT"`.

## Consequences
- One clear path; the module covers the common case (mixed on-demand/spot, labels, taints,
  autoscaler-friendly `ignore_changes` on desired size).
- What was dropped, and when you'd want it:
  - **Self-managed ASGs** — only when you need bootstrap customization managed node groups don't
    expose (custom kubelet flags, specialized AMIs). Rarely worth the upkeep now.
  - **Karpenter / Spot.io Ocean** — when bin-packing efficiency and fast, heterogeneous scaling
    matter more than the simplicity of fixed node groups. A strong choice at scale; out of scope
    for a reference, and Karpenter would be the current-day pick over a proprietary controller.
