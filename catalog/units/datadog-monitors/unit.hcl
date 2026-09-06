# Per-unit options read by live/root.hcl.
#
# This unit manages no AWS resources and its module does not declare hashicorp/aws, so it takes no
# generated AWS provider. Left on, that provider is an implicit, UNCONSTRAINED requirement for
# hashicorp/aws: init resolves it to the latest release and rewrites this unit's lockfile, which is
# how a clean clone selected 6.63.0 against modules locked at 6.62.0. See docs/adr/0012.
locals {
  aws_provider = false
}
