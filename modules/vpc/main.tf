# VPC.
#
# This is the one place the repo wraps a community module rather than writing resources directly:
# terraform-aws-modules/vpc is the de-facto standard, and reimplementing subnet/route/NAT/endpoint
# wiring by hand would be strictly worse code for a reviewer to read. Everything *else* in this
# repo is native resources; the tradeoff is discussed in docs/adr/0004.
#
# Kubernetes subnet discovery tags are applied conditionally so this module is usable with or
# without EKS.

locals {
  eks_shared_tag = var.eks_cluster_name == null ? {} : {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  public_subnet_tags = merge(
    local.eks_shared_tag,
    var.eks_cluster_name == null ? {} : { "kubernetes.io/role/elb" = "1" },
  )

  private_subnet_tags = merge(
    local.eks_shared_tag,
    var.eks_cluster_name == null ? {} : { "kubernetes.io/role/internal-elb" = "1" },
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = var.name
  cidr = var.cidr_block
  azs  = var.azs

  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets

  create_database_subnet_group = length(var.database_subnets) > 0

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags

  # Flow logs to CloudWatch: the module provisions the log group and IAM role for us.
  enable_flow_log                                 = var.enable_flow_logs
  create_flow_log_cloudwatch_log_group            = var.enable_flow_logs
  create_flow_log_cloudwatch_iam_role             = var.enable_flow_logs
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_days

  tags = var.tags
}

# Gateway endpoints for S3 and DynamoDB keep bucket/table traffic off the NAT gateways — a real
# cost saving at scale, and a security improvement (traffic never leaves the AWS network).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)
  tags              = merge(var.tags, { Name = "${var.name}-s3" })
}

data "aws_region" "current" {}
