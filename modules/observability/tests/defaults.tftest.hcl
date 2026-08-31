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

run "trace_backend_is_an_exporter_swap" {
  command = plan
  variables {
    traces_pipeline_exporters = ["otlp/jaeger"]
  }
  assert {
    condition     = can(regex("jaeger-collector", kubernetes_config_map_v1.gateway.data["config.yaml"]))
    error_message = "Selecting otlp/jaeger in traces_pipeline_exporters must point traces at Jaeger's OTLP endpoint."
  }
  assert {
    condition     = !can(regex("\n  jaeger:", kubernetes_config_map_v1.gateway.data["config.yaml"]))
    error_message = "Jaeger must be reached over OTLP; the removed `jaeger` exporter must not appear."
  }
  assert {
    condition     = can(regex("otlp/tempo", kubernetes_config_map_v1.gateway.data["config.yaml"]))
    error_message = "Adding Jaeger must not remove Tempo: both stay available as selectable backends."
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

run "exemplar_pivot_has_a_real_datasource_target" {
  command = plan

  assert {
    condition     = kubernetes_config_map_v1.datasources[0].metadata[0].labels["grafana_datasource"] == "1"
    error_message = "Datasources must be provisioned as code through the Grafana sidecar, not click-configured."
  }
  assert {
    condition     = can(regex("exemplarTraceIdDestinations", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"]))
    error_message = "The Prometheus datasource must declare an exemplar destination, or the metric to trace pivot is dead."
  }
  assert {
    condition = alltrue([
      can(regex("\"datasourceUid\": \"tempo\"", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"])),
      can(regex("\"type\": \"tempo\"", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"])),
    ])
    error_message = "By default traces go to Tempo, so the exemplar pivot must target a provisioned Tempo datasource."
  }
  assert {
    condition     = can(regex("\"name\": \"trace_id\"", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"]))
    error_message = "The exemplar destination must key on trace_id, the label the collector's remote-write translator attaches."
  }
}

run "exemplar_pivot_follows_the_trace_backend" {
  command = plan
  variables {
    traces_pipeline_exporters = ["otlp/jaeger"]
  }

  assert {
    condition = alltrue([
      can(regex("\"datasourceUid\": \"jaeger\"", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"])),
      can(regex("\"type\": \"jaeger\"", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"])),
    ])
    error_message = "Selecting Jaeger on the seam must move the exemplar pivot to Jaeger — the backend traces are sent to is the one exemplars land in."
  }
  assert {
    condition     = !can(regex("\"type\": \"tempo\"", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"]))
    error_message = "Only the selected trace backend should be provisioned as a datasource."
  }
}

run "no_exemplar_link_without_a_backend_grafana_can_query" {
  command = plan
  variables {
    exporters                 = { "otlphttp/vendor" = { endpoint = "http://collector.example.com:4318" } }
    traces_pipeline_exporters = ["otlphttp/vendor"]
    logs_pipeline_exporters   = ["otlphttp/vendor"]
  }

  assert {
    condition     = can(regex("\"exemplarTraceIdDestinations\": \\[\\]", kubernetes_config_map_v1.datasources[0].data["datasources.yaml"]))
    error_message = "With traces at a vendor endpoint there is no Grafana trace datasource, so no exemplar destination may be declared — better an empty list than a link to a uid that does not resolve."
  }
}

run "dashboards_are_templated_and_carry_exemplars" {
  command = plan

  assert {
    condition = alltrue([
      can(regex("\"name\": \"namespace\"", kubernetes_config_map_v1.dashboard_red.data["red-services.json"])),
      can(regex("\"name\": \"service\"", kubernetes_config_map_v1.dashboard_red.data["red-services.json"])),
      can(regex("service_name=~..\\$service", kubernetes_config_map_v1.dashboard_red.data["red-services.json"])),
    ])
    error_message = "RED must stay templated and the variables must actually filter the queries — one dashboard for every service, not forty snowflakes."
  }
  assert {
    condition     = can(regex("\"exemplar\": true", kubernetes_config_map_v1.dashboard_red.data["red-services.json"]))
    error_message = "RED must have an exemplar-enabled latency target."
  }
  assert {
    condition     = can(regex("http_server_request_duration_seconds_bucket", kubernetes_config_map_v1.dashboard_red.data["red-services.json"]))
    error_message = "The exemplar panel must query the raw histogram: exemplars do not survive recording-rule evaluation."
  }
  assert {
    condition     = can(regex("service:latency_p99:5m", kubernetes_config_map_v1.dashboard_red.data["red-services.json"]))
    error_message = "The precomputed p99 panel must survive — the exemplar panel is an addition, not a replacement."
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
