variable "namespace" {
  description = "Kubernetes namespace the observability components are deployed into."
  type        = string
  default     = "observability"
  nullable    = false
}

variable "environment" {
  description = "Environment name, stamped onto every telemetry record as deployment.environment for consistent filtering."
  type        = string
  nullable    = false
}

variable "service_namespace" {
  description = "Logical service namespace stamped onto telemetry as service.namespace (e.g. the platform/team name)."
  type        = string
  default     = "platform"
  nullable    = false
}

variable "collector_image" {
  description = "OpenTelemetry Collector image (contrib distribution for the exporter/receiver set)."
  type        = string
  default     = "otel/opentelemetry-collector-contrib:0.115.0"
  nullable    = false
}

variable "gateway_replicas" {
  description = "Number of gateway-collector replicas (the tier applications send OTLP to)."
  type        = number
  default     = 2
  nullable    = false
}

# ─── THE EXPORT SEAM ──────────────────────────────────────────────────────────
# Receivers and processors are cloud-agnostic and never change on a migration. The
# export path is the only thing that does, and it has ONE control surface with two
# modes, not two mechanisms:
#   • direct (var.kafka.enabled = false, the default): the gateway exports straight to
#     the backends below, with a persistent sending queue on disk so a backend blip
#     never drops data.
#   • bus (var.kafka.enabled = true): the gateway exports to Kafka (topic per signal)
#     and separate consumer collectors read from Kafka and export to these same
#     backends. The backend definitions do not change between modes — only the hop.
# Moving clouds means editing var.exporters and the pipeline lists; nothing else.
variable "exporters" {
  description = <<-EOT
    Backend exporter definitions, keyed by exporter name. THIS IS THE SEAM. Defaults keep
    everything in-cluster and portable (Prometheus remote-write for metrics, OTLP to Tempo
    for traces, OTLP/HTTP to Loki for logs) and are push-based so the persistent queue
    protects every signal. To target a managed backend, replace these (e.g. "awsemf",
    "googlecloud", "otlphttp" to a vendor endpoint) and update the pipeline lists below —
    receivers, processors, and the Kafka wiring are untouched.
  EOT
  type        = any
  default = {
    prometheusremotewrite = { endpoint = "http://prometheus.observability.svc.cluster.local:9090/api/v1/write" }
    "otlp/tempo"          = { endpoint = "tempo.observability.svc.cluster.local:4317", tls = { insecure = true } }
    "otlphttp/loki"       = { endpoint = "http://loki.observability.svc.cluster.local:3100/otlp" }
  }
  nullable = false
}

variable "metrics_pipeline_exporters" {
  description = "Backend exporter names the metrics signal fans out to (keys of var.exporters). Part of the seam."
  type        = list(string)
  default     = ["prometheusremotewrite"]
  nullable    = false
}

variable "traces_pipeline_exporters" {
  description = "Backend exporter names the traces signal fans out to. Part of the seam."
  type        = list(string)
  default     = ["otlp/tempo"]
  nullable    = false
}

variable "logs_pipeline_exporters" {
  description = "Backend exporter names the logs signal fans out to. Part of the seam."
  type        = list(string)
  default     = ["otlphttp/loki"]
  nullable    = false
}

variable "kafka" {
  description = <<-EOT
    Optional Kafka transport between the gateway collector and the backends. DEFAULT OFF: when
    disabled the module provisions no broker and exports directly with an on-disk persistent
    queue. Enable it only when the direct path is genuinely insufficient — bursty producers that
    outrun a sink, an unreliable or slow backend, or a multi-cloud dual-read during migration
    (see docs/adr/0009). The module wires collectors to an EXISTING Kafka; it does not deploy
    brokers. One topic per signal. When enabled, the bus is itself monitored (consumer lag, ISR,
    partition skew) — a blind telemetry bus is worse than none.
  EOT
  type = object({
    enabled           = optional(bool, false)
    brokers           = optional(list(string), [])
    consumer_replicas = optional(number, 2)
    topics = optional(object({
      metrics = optional(string, "otel-metrics")
      traces  = optional(string, "otel-traces")
      logs    = optional(string, "otel-logs")
    }), {})
    consumer_group = optional(string, "otel-consumers")
    max_lag_alert  = optional(number, 50000) # records; alert when a consumer group falls this far behind
  })
  default  = {}
  nullable = false

  validation {
    condition     = !coalesce(try(var.kafka.enabled, false), false) || length(try(var.kafka.brokers, [])) > 0
    error_message = "kafka.brokers must be non-empty when kafka.enabled = true."
  }
}

variable "slo_target" {
  description = "Availability SLO as a fraction (e.g. 0.999 = three nines). Drives the error-budget burn-rate thresholds."
  type        = number
  default     = 0.999
  nullable    = false

  validation {
    condition     = var.slo_target > 0.9 && var.slo_target < 1
    error_message = "slo_target must be between 0.9 and 1 (exclusive)."
  }
}

variable "pagerduty_routing_key" {
  description = "PagerDuty Events API v2 routing key for Alertmanager. Empty by default; supply via a secret/environment, never commit it."
  type        = string
  default     = ""
  nullable    = false
  sensitive   = true
}

variable "labels" {
  description = "Extra labels merged onto every resource this module creates."
  type        = map(string)
  default     = {}
  nullable    = false
}
