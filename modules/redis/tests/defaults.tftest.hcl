mock_provider "aws" {}

variables {
  name                   = "acme-prod-cache"
  subnet_ids             = ["subnet-aaa", "subnet-bbb"]
  vpc_security_group_ids = ["sg-aaa"]
}

run "encryption_always_on" {
  command = plan
  assert {
    condition     = tobool(aws_elasticache_replication_group.this.at_rest_encryption_enabled) == true
    error_message = "At-rest encryption must always be enabled."
  }
  assert {
    condition     = tobool(aws_elasticache_replication_group.this.transit_encryption_enabled) == true
    error_message = "In-transit encryption must always be enabled."
  }
}

run "failover_and_multiaz_follow_replicas" {
  command = plan
  variables {
    replicas_per_node_group = 2
  }
  assert {
    condition     = aws_elasticache_replication_group.this.automatic_failover_enabled == true
    error_message = "Automatic failover should be on when replicas exist."
  }
  assert {
    condition     = aws_elasticache_replication_group.this.multi_az_enabled == true
    error_message = "Multi-AZ should be on when replicas exist."
  }
}

run "no_failover_without_replicas" {
  command = plan
  variables {
    replicas_per_node_group = 0
  }
  assert {
    condition     = aws_elasticache_replication_group.this.automatic_failover_enabled == false
    error_message = "Failover should be off with zero replicas."
  }
}
