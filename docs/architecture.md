# Architecture

A single-region-per-account AWS platform: a VPC, an EKS cluster with managed nodes, Aurora
PostgreSQL and Redis for data, a CloudFront + WAF edge, Datadog monitors, and IAM wired for
keyless CI and workload identity. Environments are isolated by account.

![AWS topology: a management account holding a state backend, a GitHub OIDC deploy role and an IAM account baseline, and across a labelled account boundary a workload account running a VPC with EKS, its node group, add-ons, namespaces and the OpenTelemetry collector layer, alongside Aurora, Redis and Datadog monitors, plus an edge tier of Route53, ACM and CloudFront where the ACM certificate and CloudFront distribution exist only in prod](images/aws-architecture.svg)

*Read from the stack files rather than from memory: `live/management/.../global`, and the staging and
prod stacks in `live/<account>/us-west-2/<env>/terragrunt.stack.hcl`. The unit counts, instance types
and capacity types on it are the values those files actually set.*

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
