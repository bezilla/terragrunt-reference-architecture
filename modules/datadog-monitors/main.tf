# Datadog monitors as data.
#
# A module per monitor (db health, redis health, CDN basics, SSL expiry, APM error rate, log
# ingest, service replica health, synthetic availability, ...) is a common shape, each a near-exact
# copy of the same datadog_monitor scaffolding with different thresholds and queries. They collapse
# cleanly into one factory that takes a map of monitor definitions: environments and services
# differ by data, not by forked modules.
#
# The provider is configured by the caller (it needs the Datadog API/app keys); this module only
# declares the requirement.

locals {
  # Append the notification targets to each monitor's message so paging is consistent.
  monitors = {
    for id, m in var.monitors : id => merge(m, {
      targets = join(" ", coalesce(m.notify_targets, var.notification_targets))
    })
  }
}

resource "datadog_monitor" "this" {
  for_each = local.monitors

  name    = "[${var.environment}] ${each.value.name}"
  type    = each.value.type
  message = "${each.value.message} ${each.value.targets}"
  query   = each.value.query

  monitor_thresholds {
    critical = each.value.critical
    warning  = each.value.warning
  }

  priority = each.value.priority

  notify_no_data    = false
  renotify_interval = 60
  include_tags      = true

  tags = concat(["env:${var.environment}", "managed-by:opentofu"], each.value.tags)
}
