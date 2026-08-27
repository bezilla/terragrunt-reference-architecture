# Catalog unit: iam-account-baseline.
#
# Uses the module's illustrative default users/groups. Replace with your own via the inputs below.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//modules/iam-account-baseline"
}

inputs = {
  # users and groups default to illustrative example entries in the module; override here.
}
