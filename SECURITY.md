# Security

## Scope
This is a reference architecture built from placeholder values. It contains no real credentials,
account identifiers, or infrastructure. Still, if you find a security-relevant defect — an insecure
default, a module that provisions something unsafe, a policy gap — please report it.

## Reporting
Open a [private security advisory](https://github.com/bezilla/terragrunt-reference-architecture/security/advisories/new)
rather than a public issue. Include the affected module or workflow and the impact.

## What this repo does to stay clean
- No long-lived cloud credentials: CI authenticates with GitHub OIDC; workloads use IRSA.
- Secrets are never committed: gitleaks and trufflehog run on every change; database credentials
  are managed by AWS Secrets Manager; third-party keys come from the environment.
- Security scanning (trivy) and policy-as-code (conftest) gate every change.
