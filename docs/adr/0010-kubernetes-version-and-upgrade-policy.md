# 10. Kubernetes version and upgrade policy

Status: Accepted

## Context
The workload stacks pinned Kubernetes `1.31` with no written policy about when that number moves.
It had drifted out of standard support without anything noticing, because nothing in the repository
said what "supported" meant or whose job it was to check.

Amazon EKS gives each minor version **14 months of standard support**, then **12 months of extended
support** (26 months total). Extended support is not a grace period: clusters on it are billed at a
higher hourly rate, and the version stops receiving new AWS-side features. As of this ADR,
`1.34`, `1.35` and `1.36` are in standard support; `1.31`, `1.32` and `1.33` are in extended support,
with `1.33` having left standard support on 2026-07-29.

## Decision
Track a version **in standard support, one behind the newest**, and move deliberately.

`1.34` is the pin today: standard support, and far enough from the frontier that add-on and CSI
ecosystems have caught up. Being one behind the newest is the point, not laziness — `1.35` removes
cgroup v1 and ends containerd 1.x support, and `1.36` permanently disables `gitRepo` volumes and
changes SELinux volume labelling. Those are exactly the changes worth letting someone else hit first.

The version lives in the stack files (`live/<account>/<region>/<env>/terragrunt.stack.hcl`), one
value per environment, so staging can move first and prod follows.

## Sequencing
An upgrade is three ordered steps, not one:

1. **Control plane.** Bump `kubernetes_version` in staging, apply, let it settle. EKS upgrades one
   minor at a time; there is no skipping.
2. **Add-ons.** `eks-addons` pins coredns / kube-proxy / vpc-cni versions, and each has a compatibility
   matrix per Kubernetes minor. Bump them in the same change as the control plane, not after — a
   node group joining a new control plane with an old CNI is the failure people remember.
3. **Node groups.** Roll the managed node group last, so nodes join a control plane and add-on set
   that already accept them. The control plane tolerates nodes one minor behind; the reverse is not
   true.

Then repeat the whole sequence in prod. Never move both environments in one change.

## Consequences
- The pin is a decision with a date attached, not a number someone typed once.
- Standard support keeps the cluster off extended-support billing and inside the window where AWS
  ships fixes.
- One-behind-newest costs a few months of newer features and buys a version whose breaking changes
  are already documented by other people.
- This ADR does not automate the upgrade. Nothing here watches the support calendar; that remains a
  human obligation, which is the honest state of a repository that is validated but not operated.
