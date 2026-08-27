# Adding an environment

An environment is one `terragrunt.stack.hcl` plus its account/region/env config. To add, say, a
`qa` environment in the staging account:

1. **Create the config hierarchy:**
   ```
   live/staging/us-west-2/qa/env.hcl          # environment = "qa"
   ```
   `account.hcl` (account id, namespace, deploy role) and `region.hcl` (region) are inherited from
   the parent directories — you do not repeat them.

2. **Write the stack file** `live/staging/us-west-2/qa/terragrunt.stack.hcl`. Start from the
   staging stack and adjust `values` (smaller instances, `single_nat_gateway = true`, etc.):
   ```hcl
   unit "vpc" {
     source = "${get_repo_root()}/catalog/units/vpc"
     path   = "vpc"
     values = { cidr_block = "10.30.0.0/16", azs = [...], ... }
   }
   # ... the other units
   ```
   Give the new VPC a non-overlapping CIDR.

3. **Generate and validate offline:**
   ```bash
   make validate ENV=qa            # or, manually:
   cd live/staging/us-west-2/qa && terragrunt stack generate
   TG_DISABLE_BACKEND=true terragrunt run --all validate \
     --no-dependency-outputs --experiment optional-dependency-outputs
   ```

4. **Plan against real AWS** (needs credentials / the account's deploy role):
   ```bash
   make plan ENV=qa
   ```

That's the whole change: no module edits, no copied resource files. The environment differs from
its siblings only by the `values` in its stack file and its three `*.hcl` config values.
