# Production workload stack.
#
# Identical unit set to staging, production-scaled: three AZs of NAT, on-demand nodes, a
# multi-instance Aurora cluster with deletion protection. The only differences from staging are
# the `values` — the catalog units and their wiring are shared. This is the DRY payoff.

# Bootstrap unit. It creates the S3 bucket and KMS key that every OTHER unit in this
# stack stores state in, so it cannot itself live in that bucket -- it deliberately does
# not include the root config and runs on local state. Apply it ON ITS OWN, first:
#
#   terragrunt stack generate
#   (cd .terragrunt-stack/state-backend && terragrunt apply)
#
# and only then `terragrunt run --all apply`. Running everything at once races: the other
# units include root, so they try to initialise a backend in a bucket that does not exist.
unit "state_backend" {
  source = "${get_repo_root()}/catalog/units/state-backend"
  path   = "state-backend"
}

unit "vpc" {
  source = "${get_repo_root()}/catalog/units/vpc"
  path   = "vpc"
  values = {
    cidr_block         = "10.20.0.0/16"
    azs                = ["us-west-2a", "us-west-2b", "us-west-2c"]
    private_subnets    = ["10.20.0.0/19", "10.20.32.0/19", "10.20.64.0/19"]
    public_subnets     = ["10.20.96.0/22", "10.20.100.0/22", "10.20.104.0/22"]
    database_subnets   = ["10.20.108.0/24", "10.20.109.0/24", "10.20.110.0/24"]
    single_nat_gateway = false # prod: one NAT per AZ for HA
  }
}

unit "eks" {
  source = "${get_repo_root()}/catalog/units/eks"
  path   = "eks"
  values = {
    kubernetes_version     = "1.31"
    endpoint_public_access = false
  }
}

unit "eks_node_group" {
  source = "${get_repo_root()}/catalog/units/eks-managed-node-group"
  path   = "eks-node-group"
  values = {
    instance_types = ["m6i.xlarge"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 3
    min_size       = 3
    max_size       = 10
  }
}

unit "eks_addons" {
  source = "${get_repo_root()}/catalog/units/eks-addons"
  path   = "eks-addons"
  values = {}
}

unit "aurora" {
  source = "${get_repo_root()}/catalog/units/aurora-postgres"
  path   = "aurora-postgres"
  values = {
    engine_version      = "16.4"
    instance_count      = 2
    instance_class      = "db.r6g.large"
    deletion_protection = true
  }
}

unit "redis" {
  source = "${get_repo_root()}/catalog/units/redis"
  path   = "redis"
  values = {
    node_type = "cache.r7g.large"
  }
}

unit "dns" {
  source = "${get_repo_root()}/catalog/units/route53-zone"
  path   = "route53-zone"
  values = {
    zone_name = "example.com"
  }
}

unit "edge_cert" {
  source = "${get_repo_root()}/catalog/units/acm-certificate"
  path   = "acm-certificate"
  values = {
    domain_name               = "example.com"
    subject_alternative_names = ["www.example.com"]
  }
}

unit "cloudfront" {
  source = "${get_repo_root()}/catalog/units/cloudfront-waf"
  path   = "cloudfront-waf"
  values = {
    aliases            = ["www.example.com"]
    origin_domain_name = "origin.example.com"
  }
}

unit "namespace_web" {
  source = "${get_repo_root()}/catalog/units/k8s-namespace"
  path   = "namespace-web"
  values = {
    namespace = "web"
  }
}

unit "monitors" {
  source = "${get_repo_root()}/catalog/units/datadog-monitors"
  path   = "datadog-monitors"
  values = {}
}

unit "observability" {
  source = "${get_repo_root()}/catalog/units/observability"
  path   = "observability"
  values = {
    slo_target = 0.999
    kafka      = { enabled = false }
  }
}
