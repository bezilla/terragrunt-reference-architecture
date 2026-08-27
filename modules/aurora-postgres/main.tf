# Aurora PostgreSQL cluster.
#
# Modern defaults throughout:
#   - The master password is generated and rotated by RDS into Secrets Manager
#     (manage_master_user_password) — no random_password in state, no secret in tfvars. The source
#     repo hand-rolled random_password + SSM; this is strictly better.
#   - Storage is encrypted with a customer-managed KMS key.
#   - An optional RDS Proxy provides the connection seam used for blue/green major-version
#     upgrades: stand up a "green" cluster with this same module, then repoint the proxy target
#     group. See the README for the runbook.
#   - global_cluster_identifier optionally attaches the cluster to an Aurora Global Database.

resource "aws_kms_key" "db" {
  description             = "Aurora storage encryption for ${var.cluster_identifier}."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "db" {
  name          = "alias/aurora-${var.cluster_identifier}"
  target_key_id = aws_kms_key.db.key_id
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = var.cluster_identifier
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.global_cluster_identifier == null ? var.database_name : null

  master_username             = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  global_cluster_identifier = var.global_cluster_identifier

  storage_encrypted = true
  kms_key_id        = aws_kms_key.db.arn

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot        = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.cluster_identifier}-final"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.tags

  lifecycle {
    ignore_changes = [engine_version] # let controlled upgrades happen out of band
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.cluster_identifier}-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  instance_class     = var.instance_class

  db_subnet_group_name = var.subnet_group_name

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.db.arn
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.monitoring.arn

  auto_minor_version_upgrade = true
  tags                       = var.tags
}

data "aws_iam_policy_document" "monitoring_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.cluster_identifier}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
