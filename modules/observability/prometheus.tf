# Prometheus configuration-as-code: a scrape config and the RED/USE recording rules that both the
# dashboards and the SLO burn-rate alerts build on. Delivered as ConfigMaps so they are portable
# across a self-managed Prometheus (rule_files / additional-scrape-config mount) or the Prometheus
# Operator (a rules sidecar). The intent — config, not click-ops — is what matters here.

locals {
  scrape_config = yamlencode({
    scrape_configs = [
      # The collectors' own telemetry — this is how we see the telemetry path itself.
      {
        job_name              = "otel-collectors"
        scrape_interval       = "15s"
        kubernetes_sd_configs = [{ role = "pod", namespaces = { names = [var.namespace] } }]
        relabel_configs = [
          { source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_part_of"], regex = "observability", action = "keep" },
          { source_labels = ["__meta_kubernetes_pod_container_port_name"], regex = "metrics", action = "keep" },
        ]
      },
      # Node and cluster infrastructure for the USE dashboard.
      { job_name = "node-exporter", kubernetes_sd_configs = [{ role = "endpoints" }], relabel_configs = [{ source_labels = ["__meta_kubernetes_service_label_app_kubernetes_io_name"], regex = "node-exporter", action = "keep" }] },
      { job_name = "kube-state-metrics", kubernetes_sd_configs = [{ role = "endpoints" }], relabel_configs = [{ source_labels = ["__meta_kubernetes_service_label_app_kubernetes_io_name"], regex = "kube-state-metrics", action = "keep" }] },
    ]
  })

  recording_rules = yamlencode({
    groups = [
      {
        name = "red-services"
        rules = [
          { record = "service:request_rate:rate5m", expr = "sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count[5m]))" },
          { record = "service:error_rate:rate5m", expr = "sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count{http_response_status_code=~\"5..\"}[5m]))" },
          { record = "service:latency_p99:5m", expr = "histogram_quantile(0.99, sum by (service_name, service_namespace, le) (rate(http_server_request_duration_seconds_bucket[5m])))" },
          # Error ratio at the windows the burn-rate alerts pair up (5m/1h fast, 30m/6h slow).
          { record = "service:error_ratio:rate5m", expr = "sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count{http_response_status_code=~\"5..\"}[5m])) / sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count[5m]))" },
          { record = "service:error_ratio:rate30m", expr = "sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count{http_response_status_code=~\"5..\"}[30m])) / sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count[30m]))" },
          { record = "service:error_ratio:rate1h", expr = "sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count{http_response_status_code=~\"5..\"}[1h])) / sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count[1h]))" },
          { record = "service:error_ratio:rate6h", expr = "sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count{http_response_status_code=~\"5..\"}[6h])) / sum by (service_name, service_namespace) (rate(http_server_request_duration_seconds_count[6h]))" },
        ]
      },
      {
        name = "use-nodes"
        rules = [
          { record = "node:cpu_utilization:rate5m", expr = "1 - avg by (node) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))" },
          { record = "node:memory_saturation:ratio", expr = "1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)" },
          { record = "node:load_saturation:ratio", expr = "node_load5 / count by (node) (node_cpu_seconds_total{mode=\"idle\"})" },
        ]
      },
    ]
  })
}

resource "kubernetes_config_map_v1" "scrape" {
  metadata {
    name      = "prometheus-scrape-config"
    namespace = var.namespace
    labels    = local.common_labels
  }
  data = { "scrape.yaml" = local.scrape_config }
}

resource "kubernetes_config_map_v1" "recording_rules" {
  metadata {
    name      = "prometheus-recording-rules"
    namespace = var.namespace
    labels    = merge(local.common_labels, { "prometheus-rules" = "true" })
  }
  data = { "recording-rules.yaml" = local.recording_rules }
}
