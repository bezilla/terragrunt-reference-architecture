# Observability

How telemetry moves through this architecture, and why the pipeline is shaped the way it is.

The module is [`modules/observability`](modules/observability/); the decision record is
[ADR-0009](docs/adr/0009-otel-collector-and-optional-kafka-bus.md). Every claim below is drawn from
the module source — the file that backs each section is named so it can be checked.

## The argument

Observability built on cloud-vendor-native telemetry does not survive a cloud migration. The
OpenTelemetry Collector is the portability layer: instrumentation (OTLP) and pipelines (receivers +
processors) stay identical across clouds, and only the export seam changes.

This is visible in the module's provider requirements. `modules/observability/versions.tf` declares
exactly one provider — `hashicorp/kubernetes ~> 2.30` — and no vendor SDK. Nothing in the telemetry
path is bound to a monitoring vendor's API. (The incumbent `modules/datadog-monitors` is where the
`DataDog/datadog` provider lives; the two run side by side mid-migration on purpose, and the
retirement criteria are in
[ADR-0009](docs/adr/0009-otel-collector-and-optional-kafka-bus.md#coexistence-with-the-incumbent-monitoring-amendment).)

## The three signal pipelines

Source: `modules/observability/collector.tf` (receivers, processors, pipeline wiring) and
`modules/observability/variables.tf` (the exporter definitions).

The gateway collector is the tier applications send OTLP to. All three signals share one receiver
and one processor chain; they differ only in where they land.

| Signal | Receiver | Processors (in order) | Default exporter |
| --- | --- | --- | --- |
| Metrics | `otlp` | `memory_limiter` → `resource` → `batch` | `prometheusremotewrite` |
| Traces | `otlp` | `memory_limiter` → `resource` → `batch` | `otlp/tempo` |
| Logs | `otlp` | `memory_limiter` → `resource` → `batch` | `otlphttp/loki` |

The `otlp` receiver listens on gRPC `0.0.0.0:4317` and HTTP `0.0.0.0:4318`. What each processor is
for:

- **`memory_limiter`** — `check_interval = 1s`, soft limit 80% of the container's memory, spike
  limit 25%. Sheds load before the collector OOMs, so a telemetry surge degrades the pipeline
  instead of killing it.
- **`resource`** — upserts `service.namespace` (`var.service_namespace`) and
  `deployment.environment` (`var.environment`) onto every record. Consistent labelling is what lets
  one templated dashboard serve every service rather than one dashboard per service.
- **`batch`** — `timeout = 10s`, `send_batch_size = 8192`. Amortises export overhead.

The exporters are **not hardcoded**. `collector.tf` consumes `var.exporters`, whose defaults keep
everything in-cluster and push-based; the pipeline lists (`var.metrics_pipeline_exporters` and its
peers) select which of them each signal fans out to. Retargeting a backend — including moving cloud
— means editing those variables. Receivers, processors, and the Kafka wiring are untouched.

## The export seam

`var.kafka.enabled` selects between two modes with one control surface, not two mechanisms:

- **direct** (the default, `kafka.enabled = false`) — the gateway exports straight to the backends
  above, with an on-disk sending queue so a backend blip parks telemetry rather than dropping it.
- **bus** (`kafka.enabled = true`) — the gateway exports to Kafka, one topic per signal, and
  separate consumer collectors read those topics and export to the *same* backend definitions.

The backend definitions do not change between modes; only the hop does. The module wires collectors
to an **existing** Kafka — it provisions no broker. `output "transport_mode"` reports which path is
active.

## Durability: why the direct path is enough

Source: `modules/observability/collector.tf`.

Kafka is off by default because the direct path is already durable:

- A `file_storage` extension is configured at `/var/lib/otelcol/storage`, and every backend exporter
  is wrapped with `sending_queue = { enabled = true, storage = "file_storage" }` plus
  `retry_on_failure` (5s initial interval, 300s max elapsed). The queue is on disk, not in memory,
  so a collector restart does not lose what it had accepted.
- The gateway is a **StatefulSet**, not a Deployment, precisely so that each replica owns its queue.
  A `volume_claim_template` named `storage` gives every replica its own `ReadWriteOnce` 2Gi
  PersistentVolume. A shared volume would not work here: two collectors writing one queue directory
  would corrupt it.

One qualification worth stating precisely, because it is easy to over-claim: **the per-replica
PersistentVolume is the gateway's alone.** The Kafka consumer collectors
(`modules/observability/kafka-consumers.tf`) mount an `emptyDir` for the same path — in bus mode
Kafka itself is the durable buffer upstream of them, so a PVC there would be redundant.

## Recording rules

Source: `modules/observability/prometheus.tf`. Delivered as ConfigMaps — configuration as code, not
click-ops. Group `red-services`:

| Recorded series | Meaning |
| --- | --- |
| `service:request_rate:rate5m` | Rate — requests/sec |
| `service:error_rate:rate5m` | Errors — absolute 5xx rate |
| `service:latency_p99:5m` | Duration — p99 seconds |
| `service:error_ratio:rate5m` | 5xx ÷ total, 5m window |
| `service:error_ratio:rate30m` | 5xx ÷ total, 30m window |
| `service:error_ratio:rate1h` | 5xx ÷ total, 1h window |
| `service:error_ratio:rate6h` | 5xx ÷ total, 6h window |

All are aggregated `by (service_name, service_namespace)`. The four `error_ratio` windows exist for
one reason: they are exactly the windows the burn-rate alerts pair up. A second group, `use-nodes`,
records `node:cpu_utilization:rate5m`, `node:memory_saturation:ratio`, and
`node:load_saturation:ratio` for the USE dashboard.

These expressions assume the OpenTelemetry HTTP semantic conventions
(`http_server_request_duration_seconds_*`); services on other conventions need the expressions
adjusted.

## SLO burn-rate alerting

Source: `modules/observability/slo.tf`.

A static "error ratio > X" either pages on every brief spike (short window) or notices a real outage
far too late (long window). A multi-window, multi-burn-rate pair fixes both. Each alert requires a
**short and a long window to both exceed** the burn rate: the long window proves the burn is
sustained, the short window proves it is still happening now, so the alert clears quickly once
fixed.

| Alert | Windows (both must breach) | Burn rate | `for` | Severity |
| --- | --- | --- | --- | --- |
| `SLOErrorBudgetFastBurn` | `rate5m` **and** `rate1h` | 14.4× | 2m | critical → pages |
| `SLOErrorBudgetSlowBurn` | `rate30m` **and** `rate6h` | 6× | 15m | warning → ticket |

The four windows are two pairs, not a flat set — 5m pairs with 1h, and 30m pairs with 6h. Pairing
them the other way would defeat the design.

Thresholds scale with the SLO rather than being hardcoded: `budget = 1 - var.slo_target`, and the
alert fires above `14.4 × budget` (fast) or `6 × budget` (slow). At the default `slo_target = 0.999`
the fast pair trips at a 1.44% error ratio — burning roughly 2% of the monthly budget in an hour. A
tighter SLO has a smaller budget, so the same burn rate becomes a smaller absolute error ratio,
automatically.

Routing is by severity: `modules/observability/alerting.tf` maps the `severity` label onto PagerDuty
event severity, so a fast burn pages and a slow burn opens a lower-urgency incident. The routing key
is a variable, empty by default, stored in a Kubernetes Secret — never committed.

## Kafka bus monitoring

Source: `modules/observability/slo.tf`. These rules exist **only when `var.kafka.enabled`** — the
ConfigMap is conditional. A telemetry bus you cannot see is worse than no bus.

| Alert | Detects | Severity |
| --- | --- | --- |
| `KafkaConsumerLagHigh` | Consumer group lag above `var.kafka.max_lag_alert` (default 50,000 records) for 10m | warning |
| `KafkaConsumerLagGrowing` | Lag `deriv()` positive over 15m — consumers cannot keep up, so loss is coming if retention is exceeded | critical |
| `KafkaPartitionUnderReplicated` | ISR shrunk below replica count for 5m — a broker loss now risks data loss | critical |
| `KafkaPartitionSkew` | Per-partition lag spread beyond half the lag threshold — a hot partition, meaning a bad partition key or unbalanced assignment | warning |

The metrics behind these come from a `kafkametrics` receiver on the consumer collectors, scraping
`brokers`, `topics`, and `consumers` every 30s.

## Dashboards

Source: `modules/observability/grafana.tf` and `modules/observability/dashboards/`.

Two dashboards ship as committed JSON, provisioned through ConfigMaps labelled `grafana_dashboard=1`
for the kube-prometheus-stack Grafana sidecar. Both are templated so one dashboard serves every
service or node:

- **RED — Services** (`dashboards/red-services.json`, uid `red-services`) — variables `$namespace`
  and `$service`; panels *Rate — requests/sec*, *Errors — 5xx ratio*, *Duration — p99 seconds*, each
  reading the recording rules above.
- **USE — Nodes** (`dashboards/use-nodes.json`, uid `use-nodes`) — variable `$node`; panels
  *Utilization — CPU*, *Saturation — memory*, *Saturation — run-queue (load/CPU)*.

### On rendered screenshots

This document deliberately carries no dashboard screenshots. The dashboards are provisioned as code
and the JSON is in the repo, which is the reviewable artifact; a rendered image could not be
produced honestly here for two reasons:

1. **The module has no standalone runtime.** It installs neither Prometheus, Grafana, Alertmanager,
   Tempo, nor Loki — it assumes they exist and provisions the collector and the configuration that
   plugs into them. The repo ships no compose file or equivalent harness, so there is nothing to
   stand up and point a browser at.
2. **There is no error-budget-burn dashboard to capture.** Burn rate exists in this module as
   *alerting rules* (`slo.tf`), not as a Grafana panel. The closest committed panel is
   *Errors — 5xx ratio* on the RED dashboard, which plots `service:error_ratio:rate5m` — the SLI the
   burn-rate alerts are built from, but not a budget-burn visualisation.

Rendering the RED dashboard for real would take a Grafana instance with a Prometheus datasource, the
recording rules from `prometheus.tf` loaded, and a synthetic workload emitting
`http_server_request_duration_seconds_*` long enough for the 5m windows to populate. An
error-budget-burn panel would have to be authored first and committed as a third dashboard, at which
point it is a module change rather than a documentation one.

## What this does not do

- Does not install Prometheus, Grafana, Alertmanager, Tempo, or Loki.
- Does not deploy Kafka — bus mode wires to an existing broker.
- Does not instrument applications. Emitting OTLP is the app's job; this is the pipeline that
  receives it.
