# observability

A portable observability layer for the EKS stacks: an OpenTelemetry Collector, Prometheus/Grafana
configuration-as-code, SLO burn-rate alerting, and PagerDuty routing. Open-source only — no Datadog.

## The problem it solves (60 seconds)

Observability wired directly to a cloud vendor's telemetry — its agent, its metric API, its
dashboards — does not survive a move to another cloud. You re-instrument everything.

The **OpenTelemetry Collector is the portability layer.** Applications speak OTLP to a gateway
collector; the collector's **receivers and processors are identical on every cloud** and never
change. The only thing that changes on a migration is the **export seam**:

```
apps ──OTLP──▶ gateway collector ──▶  [ THE SEAM ]  ──▶ backends
                receivers + processors        exporters (var.exporters + pipeline lists)
                (fixed, portable)             (swap these, nothing else)
```

Moving from, say, Prometheus/Tempo/Loki to a managed backend is editing `var.exporters` and the
three pipeline lists — not a rewrite. `tests/defaults.tftest.hcl` asserts exactly this: swapping the
exporters variable changes the destination with no other edit.

The trace backend is the clearest example. Both supported stores speak OTLP, so choosing between
them is one variable and no application change:

| Trace backend | Exporter | Select it with |
| --- | --- | --- |
| Tempo (reference default) | `otlp/tempo` | `traces_pipeline_exporters = ["otlp/tempo"]` |
| Jaeger | `otlp/jaeger` | `traces_pipeline_exporters = ["otlp/jaeger"]` |

Both ship in the `var.exporters` default map; an exporter no pipeline references is inert, so the
unused one costs nothing. Jaeger is reached over **OTLP** (it ingests OTLP natively on 4317) — the
collector's old `jaeger` exporter was removed upstream and is deliberately not used. Point
`otlp/jaeger` at your own collector endpoint by overriding `var.exporters`.

The seam has **one control surface with two modes**, not two mechanisms:

- **direct (default):** the gateway exports straight to the backends, with an on-disk
  (`file_storage`) persistent sending queue on a per-replica PVC, so a backend blip parks telemetry
  and drains it on recovery instead of dropping it. This is sufficient on its own.
- **Kafka bus (opt-in, `var.kafka.enabled`):** the gateway exports to Kafka (one topic per signal)
  and consumer collectors read the bus and export to the *same* backends. The bus monitors itself
  (lag, ISR, partition skew). When to reach for it — and when the persistent queue is the right
  answer instead — is [ADR-0009](../../docs/adr/0009-otel-collector-and-optional-kafka-bus.md).

## What it provisions

- OTel **gateway collector** (StatefulSet) — OTLP in; `memory_limiter` + `batch` + a `resource`
  processor that stamps `service.namespace` / `deployment.environment` on every record.
- **Prometheus** scrape config + RED/USE **recording rules**.
- **Grafana dashboards as code** (committed JSON, sidecar-provisioned): one RED dashboard for
  services and one USE dashboard for nodes, each templated by `$namespace`/`$service` or `$node` so
  one dashboard serves many.
- **Trace backend as a variable:** `otlp/tempo` (default) or `otlp/jaeger`, both over OTLP.
- **SLO burn-rate alerting** — a fast (5m∧1h) + slow (30m∧6h) multi-window burn-rate pair, scaled to
  `var.slo_target`, not a raw threshold.
- **PagerDuty routing** by severity (Alertmanager).
- Optional **Kafka consumers + bus-health rules** when the bus is enabled.

## Limitations — what this does NOT do

- **It does not install Prometheus, Grafana, Alertmanager, Tempo, or Loki.** It assumes they exist
  (e.g. kube-prometheus-stack + Tempo + Loki) and provisions the collector and the config that plugs
  into them. Rules/scrape config are delivered as ConfigMaps; wiring them into your Prometheus
  (rule_files mount, operator rules sidecar, or conversion to `PrometheusRule`) is environment-
  specific.
- **It does not deploy Kafka.** In bus mode it wires collectors to an *existing* broker
  (`var.kafka.brokers`); it provisions no broker.
- **It does not instrument your applications.** Emitting OTLP is the app's job; this is the pipeline
  that receives it.
- **Consumer collectors use an emptyDir queue**, not a PVC — Kafka is the durable buffer upstream of
  them; only the gateway (the direct-mode ingress point) gets a persistent volume.
- **The RED rules assume OTel HTTP semconv** metric names (`http_server_request_duration_seconds_*`);
  services on other conventions need the recording-rule expressions adjusted.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.8 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.30 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_config_map_v1.consumer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.dashboard_red](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.dashboard_use](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.datasources](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.kafka_rules](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.recording_rules](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.scrape](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_config_map_v1.slo_rules](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_deployment_v1.consumer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment_v1) | resource |
| [kubernetes_secret_v1.alertmanager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.collector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [kubernetes_service_v1.gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1) | resource |
| [kubernetes_stateful_set_v1.gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/stateful_set_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_collector_image"></a> [collector\_image](#input\_collector\_image) | OpenTelemetry Collector image (contrib distribution for the exporter/receiver set). | `string` | `"otel/opentelemetry-collector-contrib:0.115.1"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name, stamped onto every telemetry record as deployment.environment for consistent filtering. | `string` | n/a | yes |
| <a name="input_exporters"></a> [exporters](#input\_exporters) | Backend exporter definitions, keyed by exporter name. THIS IS THE SEAM. Defaults keep<br/>everything in-cluster and portable (Prometheus remote-write for metrics, OTLP to Tempo<br/>for traces, OTLP/HTTP to Loki for logs) and are push-based so the persistent queue<br/>protects every signal. To target a managed backend, replace these (e.g. "awsemf",<br/>"googlecloud", "otlphttp" to a vendor endpoint) and update the pipeline lists below —<br/>receivers, processors, and the Kafka wiring are untouched.<br/><br/>Trace backends are an exporter swap, not a redesign: "otlp/tempo" is the reference default<br/>and "otlp/jaeger" ships alongside it for a Jaeger shop. Both speak OTLP, so the receiver,<br/>the processor chain, and the applications are identical either way — select one by naming<br/>it in var.traces\_pipeline\_exporters. | `any` | <pre>{<br/>  "otlp/jaeger": {<br/>    "endpoint": "jaeger-collector.observability.svc.cluster.local:4317",<br/>    "tls": {<br/>      "insecure": true<br/>    }<br/>  },<br/>  "otlp/tempo": {<br/>    "endpoint": "tempo.observability.svc.cluster.local:4317",<br/>    "tls": {<br/>      "insecure": true<br/>    }<br/>  },<br/>  "otlphttp/loki": {<br/>    "endpoint": "http://loki.observability.svc.cluster.local:3100/otlp"<br/>  },<br/>  "prometheusremotewrite": {<br/>    "endpoint": "http://prometheus.observability.svc.cluster.local:9090/api/v1/write"<br/>  }<br/>}</pre> | no |
| <a name="input_gateway_replicas"></a> [gateway\_replicas](#input\_gateway\_replicas) | Number of gateway-collector replicas (the tier applications send OTLP to). | `number` | `2` | no |
| <a name="input_grafana_datasources"></a> [grafana\_datasources](#input\_grafana\_datasources) | Grafana datasource provisioning, delivered as a ConfigMap labelled grafana\_datasource=1 for<br/>the kube-prometheus-stack Grafana sidecar (the same mechanism as the dashboards). This exists<br/>so the exemplar pivot has a real uid to target instead of a fabricated one.<br/><br/>The trace datasource FOLLOWS THE SEAM: whichever backend var.traces\_pipeline\_exporters selects<br/>is the one provisioned and the one exemplars pivot into — Tempo by default, Jaeger when<br/>traces\_pipeline\_exporters = ["otlp/jaeger"]. Point traces at a vendor endpoint instead and no<br/>trace datasource is provisioned and no exemplar destination is declared, rather than shipping<br/>a link to a uid that does not exist.<br/><br/>NOTE the URLs here are QUERY endpoints (what Grafana reads from), which are not the OTLP<br/>ingest endpoints in var.exporters — Tempo queries on 3200 and Jaeger on 16686 while both<br/>ingest on 4317.<br/><br/>CONFLICT: if your Grafana umbrella chart already provisions a datasource named "Prometheus",<br/>set enabled = false here (or rename via prometheus\_name/prometheus\_uid) so the two do not<br/>fight over the same name. | <pre>object({<br/>    enabled         = optional(bool, true)<br/>    prometheus_name = optional(string, "Prometheus")<br/>    prometheus_uid  = optional(string, "prometheus")<br/>    prometheus_url  = optional(string, "http://prometheus.observability.svc.cluster.local:9090")<br/>    tempo_url       = optional(string, "http://tempo.observability.svc.cluster.local:3200")<br/>    jaeger_url      = optional(string, "http://jaeger-query.observability.svc.cluster.local:16686")<br/>    # Label the collector attaches the trace id to on each exemplar. "trace_id" is not a choice<br/>    # this module makes: it is prometheustranslator.ExemplarTraceIDKey in the collector's<br/>    # remote-write translator. Overridable only for a non-OTel producer.<br/>    exemplar_trace_id_label = optional(string, "trace_id")<br/>  })</pre> | `{}` | no |
| <a name="input_kafka"></a> [kafka](#input\_kafka) | Optional Kafka transport between the gateway collector and the backends. DEFAULT OFF: when<br/>disabled the module provisions no broker and exports directly with an on-disk persistent<br/>queue. Enable it only when the direct path is genuinely insufficient — bursty producers that<br/>outrun a sink, an unreliable or slow backend, or a multi-cloud dual-read during migration<br/>(see docs/adr/0009). The module wires collectors to an EXISTING Kafka; it does not deploy<br/>brokers. One topic per signal. When enabled, the bus is itself monitored (consumer lag, ISR,<br/>partition skew) — a blind telemetry bus is worse than none. | <pre>object({<br/>    enabled           = optional(bool, false)<br/>    brokers           = optional(list(string), [])<br/>    consumer_replicas = optional(number, 2)<br/>    topics = optional(object({<br/>      metrics = optional(string, "otel-metrics")<br/>      traces  = optional(string, "otel-traces")<br/>      logs    = optional(string, "otel-logs")<br/>    }), {})<br/>    consumer_group = optional(string, "otel-consumers")<br/>    max_lag_alert  = optional(number, 50000) # records; alert when a consumer group falls this far behind<br/>  })</pre> | `{}` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Extra labels merged onto every resource this module creates. | `map(string)` | `{}` | no |
| <a name="input_logs_pipeline_exporters"></a> [logs\_pipeline\_exporters](#input\_logs\_pipeline\_exporters) | Backend exporter names the logs signal fans out to. Part of the seam. | `list(string)` | <pre>[<br/>  "otlphttp/loki"<br/>]</pre> | no |
| <a name="input_metrics_pipeline_exporters"></a> [metrics\_pipeline\_exporters](#input\_metrics\_pipeline\_exporters) | Backend exporter names the metrics signal fans out to (keys of var.exporters). Part of the seam. | `list(string)` | <pre>[<br/>  "prometheusremotewrite"<br/>]</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace the observability components are deployed into. | `string` | `"observability"` | no |
| <a name="input_pagerduty_routing_key"></a> [pagerduty\_routing\_key](#input\_pagerduty\_routing\_key) | PagerDuty Events API v2 routing key for Alertmanager. Empty by default; supply via a secret/environment, never commit it. | `string` | `""` | no |
| <a name="input_service_namespace"></a> [service\_namespace](#input\_service\_namespace) | Logical service namespace stamped onto telemetry as service.namespace (e.g. the platform/team name). | `string` | `"platform"` | no |
| <a name="input_slo_target"></a> [slo\_target](#input\_slo\_target) | Availability SLO as a fraction (e.g. 0.999 = three nines). Drives the error-budget burn-rate thresholds. | `number` | `0.999` | no |
| <a name="input_traces_pipeline_exporters"></a> [traces\_pipeline\_exporters](#input\_traces\_pipeline\_exporters) | Backend exporter names the traces signal fans out to (keys of var.exporters). Part of the seam: ["otlp/tempo"] by default, ["otlp/jaeger"] for a Jaeger backend. | `list(string)` | <pre>[<br/>  "otlp/tempo"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace the observability layer is deployed into. |
| <a name="output_otlp_grpc_endpoint"></a> [otlp\_grpc\_endpoint](#output\_otlp\_grpc\_endpoint) | In-cluster OTLP/gRPC endpoint applications send telemetry to. |
| <a name="output_otlp_http_endpoint"></a> [otlp\_http\_endpoint](#output\_otlp\_http\_endpoint) | In-cluster OTLP/HTTP endpoint applications send telemetry to. |
| <a name="output_transport_mode"></a> [transport\_mode](#output\_transport\_mode) | Whether telemetry flows direct-with-persistent-queue or over the Kafka bus. |
<!-- END_TF_DOCS -->
