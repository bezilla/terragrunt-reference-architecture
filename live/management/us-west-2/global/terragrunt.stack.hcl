# Management account, global scope.
#
# The account-wide foundations: the remote-state backend, the GitHub Actions OIDC deploy role, and
# the IAM users/groups/roles baseline. Each `unit` instantiates a catalog unit at `path` under the
# generated `.terragrunt-stack/` directory. Run `terragrunt stack generate` (or any `terragrunt
# run --all ...`) from this directory.
#
# The state bucket these units keep their state in is NOT here. It is bootstrapped once per account
# from live/management/us-west-2/bootstrap/state-backend (`make bootstrap ACCOUNT=management`) and
# must already exist before the first `run --all apply`. See docs/adr/0011.

unit "github_oidc" {
  source = "${get_repo_root()}/catalog/units/iam-github-oidc"
  path   = "iam-github-oidc"
}

unit "account_baseline" {
  source = "${get_repo_root()}/catalog/units/iam-account-baseline"
  path   = "iam-account-baseline"
}
