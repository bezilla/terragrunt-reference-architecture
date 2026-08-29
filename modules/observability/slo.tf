# SLO burn-rate alerting and Kafka bus-health alerting.
#
# Why burn-rate, not a raw error-threshold: a static "error ratio > X" either pages on every brief
# spike (short window) or notices a real outage far too late (long window). A multi-window
# multi-burn-rate pair fixes both. Each alert requires a SHORT and a LONG window to BOTH exceed the
# burn rate: the long window proves the burn is sustained (kills spike noise), the short window
# proves it is still happening now (so the alert clears quickly once fixed). Two pairs cover the
# budget at two urgencies (Google SRE workbook):
#   • fast  (5m AND 1h  at 14.4x): burning ~2% of the budget in an hour  -> page  (severity critical)
#   • slow  (30m AND 6h at  6x ):  burning ~5% of the budget in six hours -> ticket (severity warning)
# Thresholds scale with the SLO: a tighter SLO has a smaller error budget, so the same burn rate is
# a smaller absolute error ratio. budget = 1 - slo_target.

locals {
  budget         = 1 - var.slo_target
  fast_threshold = 14.4 * local.budget
  slow_threshold = 6 * local.budget

  slo_rules = yamlencode({
    groups = [{
      name = "slo-burn-rate"
      rules = [
        {
          alert  = "SLOErrorBudgetFastBurn"
          expr   = "service:error_ratio:rate5m > ${format("%.6f", local.fast_threshold)} and service:error_ratio:rate1h > ${format("%.6f", local.fast_threshold)}"
          for    = "2m"
          labels = { severity = "critical" }
          annotations = {
            summary     = "Fast error-budget burn on {{ $labels.service_name }}"
            description = "{{ $labels.service_name }} is burning error budget at >14.4x (5m and 1h windows). At this rate ~2% of the ${var.slo_target} SLO budget is gone within the hour."
          }
        },
        {
          alert  = "SLOErrorBudgetSlowBurn"
          expr   = "service:error_ratio:rate30m > ${format("%.6f", local.slow_threshold)} and service:error_ratio:rate6h > ${format("%.6f", local.slow_threshold)}"
          for    = "15m"
          labels = { severity = "warning" }
          annotations = {
            summary     = "Slow error-budget burn on {{ $labels.service_name }}"
            description = "{{ $labels.service_name }} is burning error budget at >6x (30m and 6h windows). Sustained, this exhausts a meaningful share of the ${var.slo_target} SLO budget over hours."
          }
        },
      ]
    }]
  })

  # Kafka bus health — only meaningful when the bus exists. A blind telemetry bus is worse than none.
  kafka_rules = yamlencode({
    groups = [{
      name = "kafka-telemetry-bus"
      rules = [
        {
          alert       = "KafkaConsumerLagHigh"
          expr        = "sum by (group) (kafka_consumer_group_lag_sum{group=\"${var.kafka.consumer_group}\"}) > ${var.kafka.max_lag_alert}"
          for         = "10m"
          labels      = { severity = "warning" }
          annotations = { summary = "OTel consumer group is far behind ({{ $value }} records)", description = "The telemetry consumers are lagging; downstream backends are receiving stale data." }
        },
        {
          alert       = "KafkaConsumerLagGrowing"
          expr        = "deriv(sum by (group) (kafka_consumer_group_lag_sum{group=\"${var.kafka.consumer_group}\"})[15m:]) > 0"
          for         = "15m"
          labels      = { severity = "critical" }
          annotations = { summary = "OTel consumer lag is growing", description = "Lag has increased steadily for 15m: consumers cannot keep up with producers. Telemetry loss risk if the bus retention is exceeded." }
        },
        {
          alert       = "KafkaPartitionUnderReplicated"
          expr        = "sum by (topic) (kafka_partition_replicas - kafka_partition_replicas_in_sync) > 0"
          for         = "5m"
          labels      = { severity = "critical" }
          annotations = { summary = "Under-replicated partitions on {{ $labels.topic }}", description = "ISR has shrunk below the replica count; a broker loss now risks telemetry data loss." }
        },
        {
          alert       = "KafkaPartitionSkew"
          expr        = "(max by (group, topic) (kafka_consumer_group_lag{group=\"${var.kafka.consumer_group}\"}) - min by (group, topic) (kafka_consumer_group_lag{group=\"${var.kafka.consumer_group}\"})) > ${floor(var.kafka.max_lag_alert / 2)}"
          for         = "15m"
          labels      = { severity = "warning" }
          annotations = { summary = "Uneven partition consumption on {{ $labels.topic }}", description = "Per-partition lag is badly skewed: some partitions are hot, suggesting a bad partition key or an unbalanced consumer assignment." }
        },
      ]
    }]
  })
}

resource "kubernetes_config_map_v1" "slo_rules" {
  metadata {
    name      = "prometheus-slo-rules"
    namespace = var.namespace
    labels    = merge(local.common_labels, { "prometheus-rules" = "true" })
  }
  data = { "slo-burn-rate.yaml" = local.slo_rules }
}

resource "kubernetes_config_map_v1" "kafka_rules" {
  count = var.kafka.enabled ? 1 : 0
  metadata {
    name      = "prometheus-kafka-rules"
    namespace = var.namespace
    labels    = merge(local.common_labels, { "prometheus-rules" = "true" })
  }
  data = { "kafka-bus.yaml" = local.kafka_rules }
}
