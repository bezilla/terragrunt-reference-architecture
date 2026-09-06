# 12. Generate the AWS provider only for units that use AWS

Status: Accepted

## Context
`live/root.hcl` generated `provider "aws"` into every unit that included it. Most units manage AWS
resources, so that was the DRY answer: one provider definition, with `default_tags`,
`allowed_account_ids` and the optional `assume_role`, inherited everywhere.

Three units are not like the others. `datadog-monitors` manages Datadog monitors; `k8s-namespace`
and `observability` manage Kubernetes objects. Their modules declare only `datadog` or `kubernetes`
in `required_providers`, and their committed lockfiles contain only those providers.

A `provider "aws"` block in a module that never declares `hashicorp/aws` is still a provider
*requirement* — an implicit one, carrying **no version constraint**. OpenTofu resolves an
unconstrained requirement to the newest release available, so on a clean clone:

```
[.terragrunt-stack/datadog-monitors] tofu: - Finding latest version of hashicorp/aws...
[.terragrunt-stack/datadog-monitors] tofu: - Installing hashicorp/aws v6.63.0 ...
[.terragrunt-stack/namespace-web]    tofu: - Finding latest version of hashicorp/aws...
[.terragrunt-stack/observability]    tofu: - Finding latest version of hashicorp/aws...
```

while every AWS module in the repository is locked at **6.62.0**. Three consequences, none of them
intended:

- `make validate-all` — a read-only offline check — **wrote** provider selections into the generated
  units' lockfiles.
- The version those units selected was whatever the registry had published that morning. Two clean
  clones a week apart do not resolve the same provider.
- The selection came from a provider none of those three modules use.

The AWS units were never affected: their modules constrain `aws` to `~> 6.0` and their lockfiles
pin 6.62.0, so resolution is already reproducible there. This is specifically about injection into
units that do not use AWS.

## Decision
Generate the AWS provider per unit rather than universally.

`root.hcl` reads an optional `unit.hcl` beside the unit it is included from and skips the provider
when the unit opts out:

```hcl
unit_opts_file = "${get_terragrunt_dir()}/unit.hcl"
unit_opts      = fileexists(local.unit_opts_file) ? read_terragrunt_config(local.unit_opts_file).locals : {}
aws_provider   = lookup(local.unit_opts, "aws_provider", true)
```

`get_terragrunt_dir()` resolves to the *including* unit's directory, so each unit answers for
itself, and `terragrunt stack generate` copies sibling files, so `unit.hcl` travels with the unit
into `.terragrunt-stack/`. The default is `true`: a unit that says nothing keeps the provider, so
adding an AWS unit needs no ceremony.

The opt-out is not a Terragrunt `generate` override. A child cannot redefine a `generate` block it
inherits — Terragrunt rejects that outright ("Detected generate blocks with the same name") — so
the decision has to be made where the block is written.

`k8s-namespace` and `observability` needed a second change to be able to opt out at all. Both
generated a `data "aws_eks_cluster_auth"` to mint the Kubernetes token, which genuinely requires the
AWS provider. They now use the `kubernetes` provider's `exec` block, calling `aws eks get-token`.
That removes the AWS dependency and fixes a second problem: `aws_eks_cluster_auth` resolves at plan
time and writes a token that expires in 15 minutes into state, whereas `exec` fetches one per
invocation.

## Consequences
- A clean clone resolves no unconstrained provider. `validate` selects nothing and rewrites no
  lockfile; it is genuinely read-only again.
- Live unit provider versions are reproducible: each unit gets exactly what its module's committed
  lockfile pins.
- Multi-platform hash coverage is untouched, because no lockfile changed. The existing lockfiles
  carry `darwin_arm64`, `darwin_amd64` and `linux_amd64` hashes, and adding a provider to those
  three units would have been the thing that needed a `tofu providers lock -platform=...` pass.
- Works with Stacks as they are: the marker is a file in the catalog unit, not an assumption that
  `.terragrunt-stack/` is committed.
- **Tradeoff — a repo-local convention.** `unit.hcl` is not a Terragrunt feature; it is a file this
  repository agrees to read. Someone who moves `root.hcl` to another project without it gets the
  old behaviour back silently. The alternative — deleting the `generate` block from `root.hcl` and
  adding an explicit `include` of a shared provider file to each of the eleven AWS units — is more
  self-describing at the unit level and needs no convention, at the cost of eleven more includes
  and a second copy of the account/region locals. The marker was chosen to keep `root.hcl` the
  single place the AWS provider is defined, which is the property the rest of the repository is
  organised around.
- **Tradeoff — `exec` needs the `aws` CLI** on PATH wherever plan/apply runs, which the data source
  did not. GitHub's runners ship it and the quickstart already assumes it (`aws sso login`), but a
  container image running OpenTofu without the AWS CLI will fail at provider configuration. Offline
  `validate` never configures the provider, so the validation path is unaffected.
- The Kubernetes token is no longer persisted in state. This has not been exercised against a live
  cluster in this repository — see the reference-boundary note in the README.
