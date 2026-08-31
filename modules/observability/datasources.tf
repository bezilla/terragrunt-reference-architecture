# Grafana datasources as code — the other half of the exemplar story.
#
# Exemplars are the metric→trace pivot: the collector attaches a trace id to histogram samples,
# Prometheus stores it alongside the bucket, and Grafana renders it as a clickable point on the
# latency panel. That last hop needs a trace datasource UID to jump to. This repo provisioned
# dashboards but no datasources, so there was nothing for the link to point at.
#
# Delivered the same way the dashboards are: a ConfigMap the Grafana sidecar picks up. Nothing is
# click-configured, and no UID is invented — the trace datasource is derived from the export seam,
# so the backend traces are SENT to is by construction the backend exemplars pivot INTO.

locals {
  # Which trace backend the seam selected. Both ship in var.exporters; the pipeline list picks one.
  jaeger_selected = contains(var.traces_pipeline_exporters, "otlp/jaeger")
  tempo_selected  = contains(var.traces_pipeline_exporters, "otlp/tempo")

  # Traces may also go somewhere Grafana has no first-class datasource for (a vendor OTLP endpoint).
  # In that case provision no trace datasource and declare no exemplar destination, rather than
  # linking to a UID that does not resolve.
  trace_datasource_enabled = local.jaeger_selected || local.tempo_selected

  trace_datasource = {
    uid  = local.jaeger_selected ? "jaeger" : "tempo"
    name = local.jaeger_selected ? "Jaeger" : "Tempo"
    type = local.jaeger_selected ? "jaeger" : "tempo"
    url  = local.jaeger_selected ? var.grafana_datasources.jaeger_url : var.grafana_datasources.tempo_url
  }

  # The pivot itself. `name` must equal the label the collector puts the trace id in — trace_id,
  # from the remote-write translator — or Grafana finds no id on the exemplar and renders no link.
  exemplar_destinations = local.trace_datasource_enabled ? [{
    name            = var.grafana_datasources.exemplar_trace_id_label
    datasourceUid   = local.trace_datasource.uid
    urlDisplayLabel = "View trace"
  }] : []

  datasources_yaml = yamlencode({
    apiVersion = 1
    datasources = concat(
      [{
        name      = var.grafana_datasources.prometheus_name
        uid       = var.grafana_datasources.prometheus_uid
        type      = "prometheus"
        access    = "proxy"
        url       = var.grafana_datasources.prometheus_url
        isDefault = true
        jsonData = {
          httpMethod = "POST"
          # Exemplar storage is a Prometheus server feature flag
          # (--enable-feature=exemplar-storage) on the assumed-existing Prometheus; this module
          # provisions configuration, not the server. Without it the panel flag is inert.
          exemplarTraceIdDestinations = local.exemplar_destinations
        }
      }],
      local.trace_datasource_enabled ? [{
        name   = local.trace_datasource.name
        uid    = local.trace_datasource.uid
        type   = local.trace_datasource.type
        access = "proxy"
        url    = local.trace_datasource.url
      }] : []
    )
  })
}

resource "kubernetes_config_map_v1" "datasources" {
  count = var.grafana_datasources.enabled ? 1 : 0

  metadata {
    name      = "grafana-datasources"
    namespace = var.namespace
    labels    = merge(local.common_labels, { grafana_datasource = "1" })
  }
  data = { "datasources.yaml" = local.datasources_yaml }
}
