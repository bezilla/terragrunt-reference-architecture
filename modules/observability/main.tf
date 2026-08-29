# Observability layer for the EKS stacks.
#
# The argument this module makes: observability built on cloud-vendor-native telemetry does not
# survive a cloud migration. The OpenTelemetry Collector is the portability layer — instrumentation
# (OTLP) and pipelines (receivers + processors) stay identical across clouds, and only the export
# seam changes. See docs/adr/0009 and the README.
#
# Runtimes assumed present (e.g. via kube-prometheus-stack + Tempo + Loki): Prometheus, Grafana,
# Alertmanager, and the trace/log stores. This module provisions the Collector and all the
# configuration-as-code (scrape config, recording rules, SLO burn-rate alerts, dashboards,
# alert routing) that plugs into them.

locals {
  common_labels = merge({
    "app.kubernetes.io/part-of"     = "observability"
    "app.kubernetes.io/managed-by"  = "opentofu"
    "app.kubernetes.io/environment" = var.environment
  }, var.labels)
}

resource "kubernetes_service_account_v1" "collector" {
  metadata {
    name      = "otel-collector"
    namespace = var.namespace
    labels    = local.common_labels
  }
}
