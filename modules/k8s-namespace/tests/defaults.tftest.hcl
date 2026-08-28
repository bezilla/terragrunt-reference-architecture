mock_provider "kubernetes" {}

variables {
  namespace = "web"
}

run "no_quota_by_default" {
  command = plan
  assert {
    condition     = length(kubernetes_resource_quota.this) == 0
    error_message = "No resource quota unless one is provided."
  }
}

run "quota_created_when_set" {
  command = plan
  variables {
    resource_quota = {
      requests_cpu    = "4"
      requests_memory = "8Gi"
      limits_cpu      = "8"
      limits_memory   = "16Gi"
    }
  }
  assert {
    condition     = length(kubernetes_resource_quota.this) == 1
    error_message = "A resource quota should be created when specified."
  }
}

run "editor_binding_targets_edit_clusterrole" {
  command = plan
  assert {
    condition     = kubernetes_role_binding.editors.role_ref[0].name == "edit"
    error_message = "Editors must bind to the built-in 'edit' ClusterRole."
  }
}
