# Gateway collector — the tier applications send OTLP to. It is a StatefulSet so each replica owns
# a PersistentVolume for the file_storage-backed sending queue: in the default (direct) mode a
# backend blip parks telemetry on disk and drains it on recovery rather than dropping it. This is
# why the direct path is sufficient on its own and Kafka is off by default (see ADR-0009).

locals {
  # Durability wrapper applied to every backend exporter — the persistent queue is what makes the
  # direct path safe without a broker.
  exporter_queue = {
    sending_queue    = { enabled = true, storage = "file_storage" }
    retry_on_failure = { enabled = true, initial_interval = "5s", max_elapsed_time = "300s" }
  }
  backend_exporters = { for k, v in var.exporters : k => merge(v, local.exporter_queue) }

  # Kafka exporters exist only when the bus is enabled; one topic per signal.
  kafka_exporters = var.kafka.enabled ? {
    "kafka/metrics" = merge({ brokers = var.kafka.brokers, topic = var.kafka.topics.metrics, protocol_version = "2.0.0", encoding = "otlp_proto" }, local.exporter_queue)
    "kafka/traces"  = merge({ brokers = var.kafka.brokers, topic = var.kafka.topics.traces, protocol_version = "2.0.0", encoding = "otlp_proto" }, local.exporter_queue)
    "kafka/logs"    = merge({ brokers = var.kafka.brokers, topic = var.kafka.topics.logs, protocol_version = "2.0.0", encoding = "otlp_proto" }, local.exporter_queue)
  } : {}

  # Cloud-agnostic processors — identical in every mode and on every cloud.
  processors = {
    memory_limiter = { check_interval = "1s", limit_percentage = 80, spike_limit_percentage = 25 }
    batch          = { timeout = "10s", send_batch_size = 8192 }
    # The resource processor enforces consistent service/env labeling on every record, so queries
    # and dashboards filter the same way regardless of which service emitted the telemetry.
    resource = { attributes = [
      { key = "service.namespace", value = var.service_namespace, action = "upsert" },
      { key = "deployment.environment", value = var.environment, action = "upsert" },
    ] }
  }

  # The seam: in direct mode the gateway exports to the backends; in bus mode it exports to Kafka.
  # Build the gateway config once per mode and select the rendered STRING. yamlencode() yields a
  # string, and strings unify under ?: — unlike the two differently-shaped exporter maps, which do
  # not. This is the seam: the receivers/processors/extensions below are identical between modes;
  # only the exporters and the per-pipeline exporter lists differ.
  gateway_common = {
    extensions = {
      health_check = { endpoint = "0.0.0.0:13133" }
      file_storage = { directory = "/var/lib/otelcol/storage" }
    }
    receivers  = { otlp = { protocols = { grpc = { endpoint = "0.0.0.0:4317" }, http = { endpoint = "0.0.0.0:4318" } } } }
    processors = local.processors
  }
  gateway_service_common = {
    extensions = ["health_check", "file_storage"]
    telemetry  = { metrics = { address = "0.0.0.0:8888" } }
  }

  gateway_config_direct = yamlencode(merge(local.gateway_common, {
    exporters = local.backend_exporters
    service = merge(local.gateway_service_common, {
      pipelines = {
        metrics = { receivers = ["otlp"], processors = ["memory_limiter", "resource", "batch"], exporters = var.metrics_pipeline_exporters }
        traces  = { receivers = ["otlp"], processors = ["memory_limiter", "resource", "batch"], exporters = var.traces_pipeline_exporters }
        logs    = { receivers = ["otlp"], processors = ["memory_limiter", "resource", "batch"], exporters = var.logs_pipeline_exporters }
      }
    })
  }))

  gateway_config_kafka = yamlencode(merge(local.gateway_common, {
    exporters = local.kafka_exporters
    service = merge(local.gateway_service_common, {
      pipelines = {
        metrics = { receivers = ["otlp"], processors = ["memory_limiter", "resource", "batch"], exporters = ["kafka/metrics"] }
        traces  = { receivers = ["otlp"], processors = ["memory_limiter", "resource", "batch"], exporters = ["kafka/traces"] }
        logs    = { receivers = ["otlp"], processors = ["memory_limiter", "resource", "batch"], exporters = ["kafka/logs"] }
      }
    })
  }))

  gateway_config = var.kafka.enabled ? local.gateway_config_kafka : local.gateway_config_direct
}

resource "kubernetes_config_map_v1" "gateway" {
  metadata {
    name      = "otel-gateway-config"
    namespace = var.namespace
    labels    = local.common_labels
  }
  data = { "config.yaml" = local.gateway_config }
}

resource "kubernetes_stateful_set_v1" "gateway" {
  metadata {
    name      = "otel-gateway"
    namespace = var.namespace
    labels    = local.common_labels
  }
  spec {
    service_name = "otel-gateway"
    replicas     = var.gateway_replicas
    selector { match_labels = { "app.kubernetes.io/name" = "otel-gateway" } }

    template {
      metadata { labels = merge(local.common_labels, { "app.kubernetes.io/name" = "otel-gateway" }) }
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
            name           = "otlp-grpc"
            container_port = 4317
          }
          port {
            name           = "otlp-http"
            container_port = 4318
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
          config_map { name = kubernetes_config_map_v1.gateway.metadata[0].name }
        }
      }
    }

    # Per-replica PersistentVolume for the file_storage sending queue.
    volume_claim_template {
      metadata { name = "storage" }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources { requests = { storage = "2Gi" } }
      }
    }
  }
}

resource "kubernetes_service_v1" "gateway" {
  metadata {
    name      = "otel-gateway"
    namespace = var.namespace
    labels    = local.common_labels
  }
  spec {
    selector = { "app.kubernetes.io/name" = "otel-gateway" }
    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
    }
    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
    }
    port {
      name        = "metrics"
      port        = 8888
      target_port = 8888
    }
  }
}
