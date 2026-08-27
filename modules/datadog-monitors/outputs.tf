output "monitor_ids" {
  description = "Datadog monitor IDs, keyed by the input map key."
  value       = { for id, m in datadog_monitor.this : id => m.id }
}
