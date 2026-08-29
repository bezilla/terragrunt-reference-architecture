# Plan-mode tests with a mocked kubernetes provider — no cluster, no apply. The ConfigMap/Secret
# data are computed from module locals (not provider-computed), so assertions on their rendered
# YAML exercise the real pipeline/seam logic.

mock_provider "kubernetes" {}

variables {
  environment = "prod"
}

run "direct_mode_is_the_default_and_is_durable" {
  command = plan

  assert {
    condition     = length(kubernetes_deployment_v1.consumer) == 0 && length(kubernetes_config_map_v1.kafka_rules) == 0
    error_message = "Kafka must be off by default: no consumers, no broker wiring, no bus rules."
  }
  assert {
    condition     = can(regex("prometheusremotewrite", kubernetes_config_map_v1.gateway.data["config.yaml"])) && !can(regex("kafka/metrics", kubernetes_config_map_v1.gateway.data["config.yaml"]))
    error_message = "Direct mode must export to the backends, not to Kafka."
  }
  assert {
    condition     = can(regex("sending_queue", kubernetes_config_map_v1.gateway.data["config.yaml"])) && can(regex("file_storage", kubernetes_config_map_v1.gateway.data["config.yaml"]))
    error_message = "Direct mode must carry a persistent (file_storage) sending queue so a backend blip does not drop data."
  }
  assert {
    condition     = output.transport_mode == "direct"
    error_message = "transport_mode output must report direct."
  }
}

run "processors_enforce_consistent_labeling" {
  command = plan
  assert {
    condition = alltrue([
      can(regex("memory_limiter", kubernetes_config_map_v1.gateway.data["config.yaml"])),
      can(regex("batch", kubernetes_config_map_v1.gateway.data["config.yaml"])),
      can(regex("service.namespace", kubernetes_config_map_v1.gateway.data["config.yaml"])),
      can(regex("deployment.environment", kubernetes_config_map_v1.gateway.data["config.yaml"])),
    ])
    error_message = "The gateway must run memory_limiter+batch and the resource processor must stamp service.namespace + deployment.environment."
  }
}

run "the_seam_swaps_the_backend_by_config_only" {
  command = plan
  variables {
    exporters                  = { "otlphttp/vendor" = { endpoint = "http://collector.example.com:4318" } }
    metrics_pipeline_exporters = ["otlphttp/vendor"]
    traces_pipeline_exporters  = ["otlphttp/vendor"]
    logs_pipeline_exporters    = ["otlphttp/vendor"]
  }
  assert {
    condition     = can(regex("otlphttp/vendor", kubernetes_config_map_v1.gateway.data["config.yaml"])) && !can(regex("prometheusremotewrite", kubernetes_config_map_v1.gateway.data["config.yaml"]))
    error_message = "Swapping only the exporters variable must change the destination with no other edits."
  }
}

run "gateway_is_hardened" {
  command = plan
  assert {
    condition     = kubernetes_stateful_set_v1.gateway.spec[0].template[0].spec[0].security_context[0].run_as_non_root == true
    error_message = "Gateway pod must run as non-root."
  }
  assert {
    condition     = length(kubernetes_stateful_set_v1.gateway.spec[0].volume_claim_template) == 1
    error_message = "Gateway must have a per-replica PVC for the persistent queue."
  }
}

run "kafka_mode_wires_the_bus_and_monitors_it" {
  command = plan
  variables {
    kafka = { enabled = true, brokers = ["kafka-bootstrap.kafka.svc:9092"] }
  }
  assert {
    condition     = length(kubernetes_deployment_v1.consumer) == 1 && length(kubernetes_config_map_v1.kafka_rules) == 1
    error_message = "Enabling Kafka must create consumer collectors and the bus-health rules."
  }
  assert {
    condition     = can(regex("kafka/metrics", kubernetes_config_map_v1.gateway.data["config.yaml"]))
    error_message = "In bus mode the gateway must export to Kafka (topic per signal)."
  }
  assert {
    condition     = can(regex("kafkametrics", kubernetes_config_map_v1.consumer[0].data["config.yaml"]))
    error_message = "Consumers must scrape the bus itself (kafkametrics) — a blind bus is worse than none."
  }
  assert {
    condition = alltrue([
      can(regex("KafkaConsumerLagGrowing", kubernetes_config_map_v1.kafka_rules[0].data["kafka-bus.yaml"])),
      can(regex("replicas_in_sync", kubernetes_config_map_v1.kafka_rules[0].data["kafka-bus.yaml"])),
      can(regex("KafkaPartitionSkew", kubernetes_config_map_v1.kafka_rules[0].data["kafka-bus.yaml"])),
    ])
    error_message = "Bus rules must cover lag growth, ISR shrink, and partition skew."
  }
}

run "slo_alerting_is_multi_window_burn_rate" {
  command = plan
  assert {
    condition = alltrue([
      can(regex("SLOErrorBudgetFastBurn", kubernetes_config_map_v1.slo_rules.data["slo-burn-rate.yaml"])),
      can(regex("SLOErrorBudgetSlowBurn", kubernetes_config_map_v1.slo_rules.data["slo-burn-rate.yaml"])),
      can(regex("rate5m.*rate1h", kubernetes_config_map_v1.slo_rules.data["slo-burn-rate.yaml"])),
      can(regex("rate30m.*rate6h", kubernetes_config_map_v1.slo_rules.data["slo-burn-rate.yaml"])),
    ])
    error_message = "SLO alerting must be a fast (5m/1h) + slow (30m/6h) multi-window burn-rate pair, not a raw threshold."
  }
}

run "dashboards_and_routing" {
  command = plan
  assert {
    condition     = kubernetes_config_map_v1.dashboard_red.metadata[0].labels["grafana_dashboard"] == "1" && kubernetes_config_map_v1.dashboard_use.metadata[0].labels["grafana_dashboard"] == "1"
    error_message = "RED and USE dashboards must be provisioned (grafana_dashboard sidecar label)."
  }
  assert {
    condition = alltrue([
      can(regex("pagerduty-critical", kubernetes_secret_v1.alertmanager.data["alertmanager.yaml"])),
      can(regex("severity=..critical", kubernetes_secret_v1.alertmanager.data["alertmanager.yaml"])),
    ])
    error_message = "Alert routing must map severity to PagerDuty receivers."
  }
}
