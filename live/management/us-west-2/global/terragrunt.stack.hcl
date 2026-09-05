# Management account, global scope.
#
# The account-wide foundations: the remote-state backend, the GitHub Actions OIDC deploy role, and
# the IAM users/groups/roles baseline. Each `unit` instantiates a catalog unit at `path` under the
# generated `.terragrunt-stack/` directory. Run `terragrunt stack generate` (or any `terragrunt
# run --all ...`) from this directory.

# Bootstrap unit -- apply it ON ITS OWN before `run --all`. It creates the bucket the
# other two units store their state in, and nothing here orders them, so a single
# `run --all apply` on a fresh account races the backend against its own creation.
unit "state_backend" {
  source = "${get_repo_root()}/catalog/units/state-backend"
  path   = "state-backend"
}

unit "github_oidc" {
  source = "${get_repo_root()}/catalog/units/iam-github-oidc"
  path   = "iam-github-oidc"
}

unit "account_baseline" {
  source = "${get_repo_root()}/catalog/units/iam-account-baseline"
  path   = "iam-account-baseline"
}
