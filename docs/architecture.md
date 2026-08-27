# Architecture

A single-region-per-account AWS platform: a VPC, an EKS cluster with managed nodes, Aurora
PostgreSQL and Redis for data, a CloudFront + WAF edge, Datadog monitors, and IAM wired for
keyless CI and workload identity. Environments are isolated by account.

```mermaid
flowchart TB
  subgraph mgmt["management account"]
    SB["state-backend<br/>(S3 + KMS, native locking)"]
    OIDC["iam-github-oidc<br/>(Actions deploy role)"]
    BASE["iam-account-baseline<br/>(users, groups, IRSA)"]
  end

  subgraph env["staging / prod account"]
    direction TB
    VPC["vpc<br/>3-tier subnets, NAT, flow logs"]
    subgraph k8s["EKS"]
      EKS["eks<br/>control plane, OIDC, access entries"]
      NG["managed node group<br/>IMDSv2, gp3"]
      ADD["add-ons<br/>coredns / kube-proxy / vpc-cni"]
      NS["k8s-namespace<br/>RBAC + quota"]
    end
    subgraph data["Data"]
      AUR["aurora-postgres<br/>Secrets Mgr creds, RDS Proxy"]
      RDS_ROLES["postgres-roles<br/>logical DBs on shared cluster"]
      RED["redis<br/>ElastiCache, encrypted"]
    end
    subgraph edge["Edge"]
      DNS["route53-zone"]
      ACM["acm-certificate<br/>(us-east-1)"]
      CF["cloudfront-waf<br/>CloudFront + WAFv2"]
    end
    MON["datadog-monitors"]
  end

  OIDC -. "assumes deploy role" .-> env
  VPC --> EKS --> NG
  EKS --> ADD
  EKS --> NS
  VPC --> AUR
  VPC --> RED
  AUR --> RDS_ROLES
  DNS --> ACM --> CF
  EKS -. "IRSA" .-> BASE
```

## Request path
Public traffic resolves through **Route53** to a **CloudFront** distribution, filtered by a
**WAFv2** web ACL (managed rule groups + per-IP rate limit), terminating TLS with an **ACM**
certificate issued in us-east-1. Origins are the workloads running in **EKS**, fronted by
in-cluster ingress. East-west data access stays inside the **VPC**: pods reach **Aurora** and
**Redis** through security groups, never over the public internet, with S3/DynamoDB traffic kept on
gateway endpoints.

## State & identity
Each account keeps its own state in an **S3 bucket with native locking** (no DynamoDB), encrypted
with a per-bucket KMS key. Deploys run from **GitHub Actions via OIDC** — a short-lived role, no
static keys. Inside the cluster, workloads use **IRSA** to assume scoped roles rather than sharing
node credentials.

## Environments
`staging` and `prod` are the same catalog units instantiated with different `values` (sizing, NAT
strategy, deletion protection). `management` holds the state backend, the CI OIDC provider, and the
IAM baseline. See [adding-an-environment](adding-an-environment.md).
