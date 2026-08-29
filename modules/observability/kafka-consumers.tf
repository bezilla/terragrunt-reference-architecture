# Consumer collectors — present ONLY when var.kafka.enabled. They read each signal's topic from
# the bus and export to the same backends as the direct path (local.backend_exporters), so the
# destination config is identical between modes. A kafkametrics receiver scrapes the bus itself
# (brokers, topics, consumer groups) and ships lag / ISR / partition metrics to the metrics
# backend, because a telemetry bus you cannot see is worse than no bus (see ADR-0009 and slo.tf).

locals {
  consumer_config = yamlencode({
    extensions = {
      health_check = { endpoint = "0.0.0.0:13133" }
      file_storage = { directory = "/var/lib/otelcol/storage" }
    }
    receivers = {
      "kafka/metrics" = { brokers = var.kafka.brokers, topic = var.kafka.topics.metrics, group_id = var.kafka.consumer_group, protocol_version = "2.0.0", encoding = "otlp_proto" }
      "kafka/traces"  = { brokers = var.kafka.brokers, topic = var.kafka.topics.traces, group_id = var.kafka.consumer_group, protocol_version = "2.0.0", encoding = "otlp_proto" }
      "kafka/logs"    = { brokers = var.kafka.brokers, topic = var.kafka.topics.logs, group_id = var.kafka.consumer_group, protocol_version = "2.0.0", encoding = "otlp_proto" }
      kafkametrics    = { brokers = var.kafka.brokers, protocol_version = "2.0.0", scrapers = ["brokers", "topics", "consumers"], collection_interval = "30s" }
    }
    processors = local.processors
    exporters  = local.backend_exporters
    service = {
      extensions = ["health_check", "file_storage"]
      telemetry  = { metrics = { address = "0.0.0.0:8888" } }
      pipelines = {
        metrics         = { receivers = ["kafka/metrics"], processors = ["memory_limiter", "batch"], exporters = var.metrics_pipeline_exporters }
        traces          = { receivers = ["kafka/traces"], processors = ["memory_limiter", "batch"], exporters = var.traces_pipeline_exporters }
        logs            = { receivers = ["kafka/logs"], processors = ["memory_limiter", "batch"], exporters = var.logs_pipeline_exporters }
        "metrics/kafka" = { receivers = ["kafkametrics"], processors = ["memory_limiter", "resource", "batch"], exporters = var.metrics_pipeline_exporters }
      }
    }
  })
}

resource "kubernetes_config_map_v1" "consumer" {
  count = var.kafka.enabled ? 1 : 0
  metadata {
    name      = "otel-consumer-config"
    namespace = var.namespace
    labels    = local.common_labels
  }
  data = { "config.yaml" = local.consumer_config }
}

resource "kubernetes_deployment_v1" "consumer" {
  count = var.kafka.enabled ? 1 : 0
  metadata {
    name      = "otel-consumer"
    namespace = var.namespace
    labels    = local.common_labels
  }
  spec {
    replicas = var.kafka.consumer_replicas
    selector { match_labels = { "app.kubernetes.io/name" = "otel-consumer" } }
    template {
      metadata { labels = merge(local.common_labels, { "app.kubernetes.io/name" = "otel-consumer" }) }
      spec {
        service_account_name = kubernetes_service_account_v1.collector.metadata[0].name
        security_context {
          run_as_non_root = true
          fs_group        = 10001
        }
        container {
          name  = "collector"
          image = var.collector_image
          args  = ["--config=/etc/otelcol/config.yaml"]
          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "1", memory = "512Mi" }
          }
          security_context {
            run_as_non_root            = true
            run_as_user                = 10001
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities { drop = ["ALL"] }
          }
          port {
            name           = "metrics"
            container_port = 8888
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/otelcol"
          }
          volume_mount {
            name       = "storage"
            mount_path = "/var/lib/otelcol/storage"
          }
          liveness_probe {
            http_get {
              path = "/"
              port = 13133
            }
          }
        }
        volume {
          name = "config"
          config_map { name = kubernetes_config_map_v1.consumer[0].metadata[0].name }
        }
        volume {
          name = "storage"
          empty_dir {}
        }
      }
    }
  }
}
