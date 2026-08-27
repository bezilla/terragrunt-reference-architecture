output "cluster_endpoint" {
  description = "Writer endpoint for the cluster."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader (load-balanced) endpoint for the cluster."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_arn" {
  description = "ARN of the cluster."
  value       = aws_rds_cluster.this.arn
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the RDS-managed master credentials."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint, or null when the proxy is disabled."
  value       = var.create_proxy ? aws_db_proxy.this[0].endpoint : null
}
