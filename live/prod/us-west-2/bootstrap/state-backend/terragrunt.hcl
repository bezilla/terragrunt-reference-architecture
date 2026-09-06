# State backend bootstrap for this account and region.
#
# Once per account, by hand, before the account's stack is applied for the first time -- and then
# essentially never again. It is a plain unit directory, deliberately outside every
# terragrunt.stack.hcl, so `terragrunt run --all` from a stack directory cannot reach it: no plan,
# apply, destroy or drift run touches the bucket the rest of the account stores its state in.
#
# The definition is shared from catalog/units/state-backend; this file exists to place it in the
# account/region hierarchy, where account.hcl and region.hcl resolve as parents.
#
#   make bootstrap ACCOUNT=<account>
#
# Its state is a local terraform.tfstate in this directory (gitignored, and left alone by
# `make clean`). Read docs/adr/0011 before assuming a second machine can just re-run this.

include "unit" {
  path = "${get_repo_root()}/catalog/units/state-backend/terragrunt.hcl"
}
