# Kubernetes namespace with baseline RBAC and an optional resource quota.
#
# Namespace owners are a variable of RBAC group subjects with generic defaults, not a hard-coded
# list of individual email addresses, so no person is baked into the module.

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = merge(
      {
        "app.kubernetes.io/managed-by" = "opentofu"
        "owner"                        = var.owner_team
      },
      var.labels,
    )
  }
}

# Bind the editor groups to the built-in "edit" ClusterRole, scoped to this namespace.
resource "kubernetes_role_binding" "editors" {
  metadata {
    name      = "${var.namespace}-editors"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  dynamic "subject" {
    for_each = toset(var.editor_group_subjects)
    content {
      api_group = "rbac.authorization.k8s.io"
      kind      = "Group"
      name      = subject.value
    }
  }
}

resource "kubernetes_resource_quota" "this" {
  count = var.resource_quota == null ? 0 : 1

  metadata {
    name      = "${var.namespace}-quota"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quota.requests_cpu
      "requests.memory" = var.resource_quota.requests_memory
      "limits.cpu"      = var.resource_quota.limits_cpu
      "limits.memory"   = var.resource_quota.limits_memory
    }
  }
}
