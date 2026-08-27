# Catalog unit: datadog-monitors. Generates a datadog provider from environment variables.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}//modules/datadog-monitors"
}
# Datadog keys come from the environment (never committed). Empty defaults keep offline validate
# working; real runs export DD_API_KEY / DD_APP_KEY.
generate "datadog_provider" {
  path      = "provider_datadog.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROV
provider "datadog" {
  api_key = "${get_env("DD_API_KEY", "")}"
  app_key = "${get_env("DD_APP_KEY", "")}"
}
PROV
}
inputs = {
  environment = include.root.locals.environment
  monitors = {
    api_5xx = {
      name     = "api 5xx rate elevated"
      type     = "metric alert"
      query    = "sum(last_5m):sum:trace.http.request.errors{env:${include.root.locals.environment}}.as_count() > 50"
      message  = "API 5xx error rate is elevated."
      critical = 50
      warning  = 25
      priority = 2
    }
  }
}
