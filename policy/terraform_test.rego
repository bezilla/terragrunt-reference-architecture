package main

import rego.v1

_tags := {"Namespace": "acme", "Environment": "prod", "ManagedBy": "opentofu-terragrunt"}

# --- mandatory tags ---
test_tagged_resource_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		{"address": "aws_kms_key.x", "type": "aws_kms_key", "change": {"after": {"tags_all": _tags}}},
	]}
}

test_missing_tag_denied if {
	count(deny) > 0 with input as {"resource_changes": [
		{"address": "aws_kms_key.x", "type": "aws_kms_key", "change": {"after": {"tags_all": {"Namespace": "acme"}}}},
	]}
}

# --- public ingress ---
test_open_ingress_denied if {
	count(deny) > 0 with input as {"resource_changes": [
		{"address": "aws_vpc_security_group_ingress_rule.ssh", "type": "aws_vpc_security_group_ingress_rule", "change": {"after": {"cidr_ipv4": "0.0.0.0/0", "tags": {}}}},
	]}
}

test_open_ingress_allowed_on_alb if {
	count(deny) == 0 with input as {"resource_changes": [
		{"address": "aws_vpc_security_group_ingress_rule.https", "type": "aws_vpc_security_group_ingress_rule", "change": {"after": {"cidr_ipv4": "0.0.0.0/0", "tags": {"role": "alb"}}}},
	]}
}

# --- encryption ---
test_unencrypted_rds_denied if {
	count(deny) > 0 with input as {"resource_changes": [
		{"address": "aws_rds_cluster.db", "type": "aws_rds_cluster", "change": {"after": {"storage_encrypted": false}}},
	]}
}

test_encrypted_rds_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		{"address": "aws_rds_cluster.db", "type": "aws_rds_cluster", "change": {"after": {"storage_encrypted": true}}},
	]}
}

test_unencrypted_redis_denied if {
	count(deny) > 0 with input as {"resource_changes": [
		{"address": "aws_elasticache_replication_group.r", "type": "aws_elasticache_replication_group", "change": {"after": {"at_rest_encryption_enabled": false}}},
	]}
}

# --- IMDSv2 ---
test_imdsv1_denied if {
	count(deny) > 0 with input as {"resource_changes": [
		{"address": "aws_launch_template.n", "type": "aws_launch_template", "change": {"after": {"metadata_options": [{"http_tokens": "optional"}]}}},
	]}
}

test_imdsv2_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		{"address": "aws_launch_template.n", "type": "aws_launch_template", "change": {"after": {"metadata_options": [{"http_tokens": "required"}]}}},
	]}
}

# --- kubernetes labels ---
test_labeled_k8s_resource_passes if {
	count(deny) == 0 with input as {"resource_changes": [
		{"address": "kubernetes_config_map_v1.x", "type": "kubernetes_config_map_v1", "change": {"after": {"metadata": [{"labels": {"app.kubernetes.io/managed-by": "opentofu"}}]}}},
	]}
}

test_unlabeled_k8s_resource_denied if {
	count(deny) > 0 with input as {"resource_changes": [
		{"address": "kubernetes_config_map_v1.x", "type": "kubernetes_config_map_v1", "change": {"after": {"metadata": [{"labels": {"app.kubernetes.io/part-of": "observability"}}]}}},
	]}
}
