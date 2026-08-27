# Adding a module

Two steps: write the module, then expose it as a catalog unit that environments can instantiate.

## 1. The module (`modules/<name>/`)
Every module follows the same shape:
- `versions.tf` — `required_version = "~> 1.8"` and `required_providers` with `~>` bounds.
- `variables.tf` — a `description` and `type` on every variable; `validation` where a bad value is
  catchable; `nullable = false` where null would be a bug; `sensitive = true` where appropriate.
- `main.tf` (+ topic files) — resources. Baseline tags come from the provider `default_tags`; keep a
  `tags` variable only for additions.
- `outputs.tf` — a `description` on every output; export only what a caller consumes.
- `README.md` — generated: `terraform-docs markdown table --output-file README.md --output-mode inject .`
- `.terraform.lock.hcl` — multi-platform: `tofu providers lock -platform=darwin_arm64 -platform=darwin_amd64 -platform=linux_amd64`
- Optional `tests/*.tftest.hcl` — a `mock_provider "aws" {}` and a couple of `run` assertions
  (see `modules/aurora-postgres/tests`).

Before committing, the module must be clean under: `tofu fmt`, `tofu validate`, `tflint`,
`trivy config .`. Fix findings; suppress only with an inline `#trivy:ignore:AVD-...` and a reason.

## 2. The catalog unit (`catalog/units/<name>/terragrunt.hcl`)
```hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true                     # exposes include.root.locals.{namespace,environment,account_id}
}

terraform {
  source = "${get_repo_root()}//modules/<name>"
}

dependency "vpc" {                  # for each thing this unit consumes
  config_path = "../vpc"
  mock_outputs = { vpc_id = "vpc-mock" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  some_input = values.some_input    # from the stack's unit block
  vpc_id     = dependency.vpc.outputs.vpc_id
}
```
Every `dependency` **must** have `mock_outputs` so `make validate` works from a clean clone.

### Non-AWS or aliased providers
The root generates only the default AWS provider. A unit needing another provider generates it
itself (a `generate` block writing a *separate* file — never a second `generate "provider"`, which
collides with root):
- **Kubernetes** — see `catalog/units/k8s-namespace` (wires a `kubernetes` provider to the eks
  dependency's outputs).
- **Datadog** — see `catalog/units/datadog-monitors` (reads keys from `DD_API_KEY` / `DD_APP_KEY`).
- **us-east-1 aliased AWS** (CloudFront/ACM) — see `catalog/units/cloudfront-waf` and
  `acm-certificate` (generate an `aws.us_east_1` alias satisfying the module's
  `configuration_aliases`).

## 3. Instantiate it
Add a `unit "<name>" { source = "${get_repo_root()}/catalog/units/<name>"; path = "<name>"; values = {...} }`
block to the relevant `terragrunt.stack.hcl`, then `make validate ENV=<env>`.
