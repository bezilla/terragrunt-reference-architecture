# Optional RDS Proxy: the connection seam for blue/green major-version upgrades and for pooling
# connections from serverless / high-fan-out workloads.

data "aws_iam_policy_document" "proxy_assume_role" {
  count = var.create_proxy ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "proxy" {
  count              = var.create_proxy ? 1 : 0
  name               = "${var.cluster_identifier}-proxy"
  assume_role_policy = data.aws_iam_policy_document.proxy_assume_role[0].json
  tags               = var.tags
}

resource "aws_db_proxy" "this" {
  count = var.create_proxy ? 1 : 0

  name                   = var.cluster_identifier
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy[0].arn
  vpc_security_group_ids = var.vpc_security_group_ids
  vpc_subnet_ids         = data.aws_db_subnet_group.this[0].subnet_ids
  require_tls            = true

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_rds_cluster.this.master_user_secret[0].secret_arn
  }

  tags = var.tags
}

data "aws_db_subnet_group" "this" {
  count = var.create_proxy ? 1 : 0
  name  = var.subnet_group_name
}

resource "aws_db_proxy_default_target_group" "this" {
  count         = var.create_proxy ? 1 : 0
  db_proxy_name = aws_db_proxy.this[0].name
}

resource "aws_db_proxy_target" "this" {
  count = var.create_proxy ? 1 : 0

  db_proxy_name         = aws_db_proxy.this[0].name
  target_group_name     = aws_db_proxy_default_target_group.this[0].name
  db_cluster_identifier = aws_rds_cluster.this.id
}
