# Redis via ElastiCache replication group.
#
# Encryption at rest and in transit are on by default and not toggleable — there is no good reason
# to run a cache without them, and leaving them optional invites an insecure environment override.
# Automatic failover follows from having replicas.

resource "aws_elasticache_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "Redis replication group ${var.name}."

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.vpc_security_group_ids

  num_node_groups            = var.num_node_groups
  replicas_per_node_group    = var.replicas_per_node_group
  automatic_failover_enabled = var.replicas_per_node_group > 0
  multi_az_enabled           = var.replicas_per_node_group > 0

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 7
  maintenance_window       = "sun:05:00-sun:06:00"

  tags = var.tags
}
