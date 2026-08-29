# In-database roles, logical databases, and credentials on a shared Aurora cluster.
#
# A shared-cluster, many-databases pattern: rather than a
# separate RDS cluster per application, one Aurora cluster hosts many logical databases, each
# owned by its own PostgreSQL role with a generated password. Credentials are written to SSM
# Parameter Store (SecureString) for applications to read at deploy time.
#
# The postgresql provider is configured by the *caller* (it needs to connect to the cluster,
# typically through a bastion or from within the VPC), so this module declares the provider
# requirement but not a provider block.

resource "random_password" "role" {
  for_each = var.databases

  length           = 32
  special          = true
  override_special = "!#%*_-+"
}

resource "postgresql_role" "owner" {
  for_each = var.databases

  name     = each.value.owner_role
  login    = true
  password = random_password.role[each.key].result

  # Don't leak the password into logs or plan output beyond what's necessary.
  skip_reassign_owned = false
}

resource "postgresql_database" "this" {
  for_each = var.databases

  name              = each.key
  owner             = postgresql_role.owner[each.key].name
  allow_connections = true
}

resource "aws_ssm_parameter" "password" {
  for_each = var.databases

  name        = "${var.secret_prefix}/${each.key}/${each.value.owner_role}/password"
  description = "Generated password for role ${each.value.owner_role} on database ${each.key}."
  type        = "SecureString"
  value       = random_password.role[each.key].result
  tags        = var.tags
}
