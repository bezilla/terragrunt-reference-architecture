# Catalog unit: route53-zone. No dependencies.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/route53-zone"
}
inputs = {
  zone_name = values.zone_name
}
