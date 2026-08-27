# Staging workload stack.
#
# The full application platform for one environment, expressed once. prod/ instantiates the same
# catalog units with production-scaled values — this is the DRY win over the source system, where
# each environment was ~70 hand-copied unit directories. Run `terragrunt stack generate` then
# `terragrunt run --all <cmd>` from here (or `make plan ENV=staging`).

unit "vpc" {
  source = "${get_repo_root()}/catalog/units/vpc"
  path   = "vpc"
  values = {
    cidr_block         = "10.10.0.0/16"
    azs                = ["us-west-2a", "us-west-2b", "us-west-2c"]
    private_subnets    = ["10.10.0.0/19", "10.10.32.0/19", "10.10.64.0/19"]
    public_subnets     = ["10.10.96.0/22", "10.10.100.0/22", "10.10.104.0/22"]
    database_subnets   = ["10.10.108.0/24", "10.10.109.0/24", "10.10.110.0/24"]
    single_nat_gateway = true # staging: one NAT to save cost
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
    instance_types = ["m6i.large"]
    capacity_type  = "SPOT" # staging tolerates spot interruptions
    desired_size   = 2
    min_size       = 1
    max_size       = 4
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
    instance_count      = 1
    instance_class      = "db.t4g.medium"
    deletion_protection = false
  }
}

unit "redis" {
  source = "${get_repo_root()}/catalog/units/redis"
  path   = "redis"
  values = {
    node_type = "cache.t4g.small"
  }
}

unit "dns" {
  source = "${get_repo_root()}/catalog/units/route53-zone"
  path   = "route53-zone"
  values = {
    zone_name = "staging.example.com"
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
