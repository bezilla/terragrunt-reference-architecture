# Grafana dashboards as code. Committed JSON, provisioned via ConfigMaps labelled for the
# kube-prometheus-stack Grafana sidecar (grafana_dashboard=1) — never click-configured. Both use
# template variables so one dashboard serves every service/node rather than one dashboard each:
#   • RED (services): rate, errors, duration, filtered by $namespace / $service.
#   • USE (nodes):    utilization, saturation, errors, filtered by $node.

resource "kubernetes_config_map_v1" "dashboard_red" {
  metadata {
    name      = "grafana-dashboard-red-services"
    namespace = var.namespace
    labels    = merge(local.common_labels, { grafana_dashboard = "1" })
  }
  data = { "red-services.json" = file("${path.module}/dashboards/red-services.json") }
}

resource "kubernetes_config_map_v1" "dashboard_use" {
  metadata {
    name      = "grafana-dashboard-use-nodes"
    namespace = var.namespace
    labels    = merge(local.common_labels, { grafana_dashboard = "1" })
  }
  data = { "use-nodes.json" = file("${path.module}/dashboards/use-nodes.json") }
}
