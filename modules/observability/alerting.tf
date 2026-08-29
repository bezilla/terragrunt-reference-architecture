# Alert routing to PagerDuty, by severity. The burn-rate and Kafka rules attach a `severity` label
# (critical | warning); Alertmanager routes on it and maps it to PagerDuty's event severity, so a
# fast burn pages and a slow burn opens a lower-urgency incident. The routing key is a secret,
# supplied at deploy time (var.pagerduty_routing_key, empty by default) and stored in a Kubernetes
# Secret — never committed.

locals {
  alertmanager_config = yamlencode({
    route = {
      receiver        = "pagerduty-warning"
      group_by        = ["alertname", "service_name", "service_namespace"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "4h"
      routes = [
        { matchers = ["severity=\"critical\""], receiver = "pagerduty-critical" },
        { matchers = ["severity=\"warning\""], receiver = "pagerduty-warning" },
      ]
    }
    receivers = [
      {
        name = "pagerduty-critical"
        pagerduty_configs = [{
          routing_key = var.pagerduty_routing_key
          severity    = "critical"
          description = "{{ .CommonAnnotations.summary }}"
        }]
      },
      {
        name = "pagerduty-warning"
        pagerduty_configs = [{
          routing_key = var.pagerduty_routing_key
          severity    = "warning"
          description = "{{ .CommonAnnotations.summary }}"
        }]
      },
    ]
  })
}

resource "kubernetes_secret_v1" "alertmanager" {
  metadata {
    name      = "alertmanager-config"
    namespace = var.namespace
    labels    = local.common_labels
  }
  type = "Opaque"
  data = { "alertmanager.yaml" = local.alertmanager_config }
}
