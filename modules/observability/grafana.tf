# Grafana dashboards as code. Committed JSON, provisioned via ConfigMaps labelled for the
# kube-prometheus-stack Grafana sidecar (grafana_dashboard=1) — never click-configured. Both use
# template variables so one dashboard serves every service/node rather than one dashboard each:
#   • RED (services): rate, errors, duration, filtered by $namespace / $service.
#   • USE (nodes):    utilization, saturation, errors, filtered by $node.
#
# Panels reference the Prometheus datasource BY NAME, so that name cannot be hardcoded here: the
# datasource variable documents renaming as the way out of a name collision with an existing
# Grafana chart, and a hardcoded name would silently orphan every panel the moment you took that
# advice. Rendered through templatefile so the dashboards follow prometheus_name wherever it goes.

resource "kubernetes_config_map_v1" "dashboard_red" {
  metadata {
    name      = "grafana-dashboard-red-services"
    namespace = var.namespace
    labels    = merge(local.common_labels, { grafana_dashboard = "1" })
  }
  data = { "red-services.json" = templatefile("${path.module}/dashboards/red-services.json", { datasource = var.grafana_datasources.prometheus_name }) }
}

resource "kubernetes_config_map_v1" "dashboard_use" {
  metadata {
    name      = "grafana-dashboard-use-nodes"
    namespace = var.namespace
    labels    = merge(local.common_labels, { grafana_dashboard = "1" })
  }
  data = { "use-nodes.json" = templatefile("${path.module}/dashboards/use-nodes.json", { datasource = var.grafana_datasources.prometheus_name }) }
}
