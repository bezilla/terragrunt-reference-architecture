output "primary_endpoint_address" {
  description = "Primary endpoint (cluster-mode-disabled) address."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "configuration_endpoint_address" {
  description = "Configuration endpoint (cluster-mode-enabled) address."
  value       = aws_elasticache_replication_group.this.configuration_endpoint_address
}
