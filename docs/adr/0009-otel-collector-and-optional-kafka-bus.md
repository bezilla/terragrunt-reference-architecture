# 9. OpenTelemetry Collector as the portability layer, with an optional Kafka bus

Status: Accepted

## Context
Observability is the part of a platform most likely to be quietly welded to one cloud. Vendor
agents, a vendor metrics API, and vendor-hosted dashboards each feel convenient in isolation, and
together they mean that moving clouds is a re-instrumentation project across every service. The
question is where to put the seam so that a migration touches configuration, not code — and, given
that seam, how telemetry should travel from producers to backends.

## Decision
**Instrument to OTLP and route everything through an OpenTelemetry Collector.** Applications emit
OTLP to a gateway collector whose receivers and processors are identical on every cloud. The only
cloud-specific surface is the collector's exporters. Migrating backends is editing the exporter
definitions and the per-signal pipeline lists; receivers, processors, instrumentation, dashboards,
and alert rules do not change.

**Make the collector's export path a single control surface with two modes, direct by default.**
The default is direct export with an on-disk persistent sending queue (`file_storage` on a
per-replica volume). A Kafka bus is available behind one variable and is **off** unless the direct
path is genuinely insufficient. Both modes export to the *same* backend definitions; Kafka only
changes the hop in between.

## Consequences
- One instrumentation standard (OTLP) and one place — the collector — to reason about batching,
  memory limits, and consistent `service.namespace` / `deployment.environment` labeling.
- A migration is a diff on the exporter block, provable in a test (swap the variable, watch the
  destination change and nothing else).
- Two more components to run (the collector tier, and Kafka if enabled) than talking straight to a
  backend. That cost is the price of the seam; it is justified because the alternative cost —
  re-instrumenting on a migration — is far larger and lands all at once.

### Rejected
- **Vendor agents / direct SDK-to-backend export.** Both weld instrumentation to a backend: the
  agent speaks a vendor protocol, and an SDK exporter aimed at a specific backend hard-codes the
  destination into every service. Either way the seam ends up inside the applications, which is the
  most expensive possible place to move it. The collector pulls the seam out into infrastructure.
- **Kafka on by default.** A broker in the telemetry path is real cost and real operational load,
  and a bus you cannot see is worse than no bus. It is not warranted for the common case.

### When the Kafka bus *is* justified — and when it is not
The persistent queue already absorbs the ordinary failure: a backend that is briefly down or slow
while the collector stays up. Reach for Kafka only when the shape of the load defeats a per-replica
queue:
- **Bursty producers that outrun the sink** — spikes large enough that a bounded on-disk queue
  would fill before the backend drains it; the bus provides deep, shared buffering.
- **An unreliable or slow sink** — sustained backend degradation measured in hours, where you want
  decoupling and replay rather than backpressure into the collectors.
- **Multi-cloud dual-read during a migration** — two independent consumer groups reading one stream
  to write the same telemetry into the old and new backends simultaneously, so you can cut over on
  confidence rather than hope.

Below that bar, Kafka is unjustified cost and operational load, and the collector's persistent queue
is the right answer. And because Kafka, when enabled, sits directly in the telemetry path, it is
itself monitored — consumer lag, lag *growth*, ISR shrink, and partition skew all alert — so the bus
cannot fail silently and take the telemetry down with it.
