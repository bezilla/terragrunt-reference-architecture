mock_provider "datadog" {}

variables {
  environment = "prod"
  monitors = {
    a = { name = "a", type = "metric alert", query = "avg(last_5m):x > 1", message = "boom", critical = 1 }
    b = { name = "b", type = "metric alert", query = "avg(last_5m):y > 2", message = "bang", critical = 2, notify_targets = ["@pagerduty-Core"] }
  }
}

run "creates_one_monitor_per_map_entry" {
  command = plan
  assert {
    condition     = length(datadog_monitor.this) == 2
    error_message = "One monitor per map entry."
  }
}

run "default_targets_appended_to_message" {
  command = plan
  # Monitor 'a' has no override, so the default notification target must appear in its message.
  assert {
    condition     = can(regex("@slack-platform-alerts", datadog_monitor.this["a"].message))
    error_message = "Default notification target should be appended when no override is given."
  }
}

run "per_monitor_override_wins" {
  command = plan
  assert {
    condition     = can(regex("@pagerduty-Core", datadog_monitor.this["b"].message))
    error_message = "Per-monitor notify_targets override should be used."
  }
}
