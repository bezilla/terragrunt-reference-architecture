# Policy-as-code gate, evaluated against `tofu show -json <plan>` output.
#
# Deliberately small and high-signal: four rules that encode the non-negotiables this repo already
# builds in, so a future change that regresses them fails CI. Run in the plan pipeline against a
# real plan; the unit tests in terraform_test.rego exercise the rules offline.
package main

import rego.v1

mandatory_tags := {"Namespace", "Environment", "ManagedBy"}

# 1. Mandatory baseline tags (supplied by the provider default_tags) on every taggable resource.
deny contains msg if {
	some rc in input.resource_changes
	tags := rc.change.after.tags_all
	is_object(tags)
	some key in mandatory_tags
	not tags[key]
	msg := sprintf("%s is missing mandatory tag %q", [rc.address, key])
}

# 2. No ingress from 0.0.0.0/0 except on rules explicitly tagged role=alb (public load balancers).
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_vpc_security_group_ingress_rule"
	rc.change.after.cidr_ipv4 == "0.0.0.0/0"
	not is_alb_rule(rc)
	msg := sprintf("%s allows ingress from 0.0.0.0/0 without tag role=alb", [rc.address])
}

is_alb_rule(rc) if rc.change.after.tags.role == "alb"

# 3. Encryption at rest is mandatory for stateful stores.
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_rds_cluster"
	rc.change.after.storage_encrypted != true
	msg := sprintf("%s: storage_encrypted must be true", [rc.address])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_elasticache_replication_group"
	not at_rest_encryption_on(rc)
	msg := sprintf("%s: at_rest_encryption_enabled must be true", [rc.address])
}

at_rest_encryption_on(rc) if rc.change.after.at_rest_encryption_enabled == true

at_rest_encryption_on(rc) if rc.change.after.at_rest_encryption_enabled == "true"

# 4. IMDSv2 required on every launch template (blocks the SSRF-to-credentials path).
deny contains msg if {
	some rc in input.resource_changes
	rc.type == "aws_launch_template"
	some opts in rc.change.after.metadata_options
	opts.http_tokens != "required"
	msg := sprintf("%s: IMDSv2 (metadata http_tokens=required) must be enforced", [rc.address])
}
