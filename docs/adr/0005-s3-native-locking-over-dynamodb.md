# 5. S3 native state locking, no DynamoDB table

Status: Accepted

## Context
The S3 backend historically required a companion DynamoDB table for state locking. Since the S3
backend gained conditional-write locking (`use_lockfile`), the DynamoDB table is optional; the
Terraform S3 backend has marked the DynamoDB locking arguments deprecated, and OpenTofu supports
the lockfile approach. The source system provisioned and referenced a
`*-state-locks` DynamoDB table everywhere.

## Decision
Use `use_lockfile = true` in the `remote_state` config and provision no DynamoDB table. The
`state-backend` module creates only the S3 bucket (plus a KMS key).

## Consequences
- One fewer resource to provision, tag, and pay for; a smaller IAM policy for state access.
- Locking uses an S3 object written with `If-None-Match`; contention surfaces as a lock error just
  as before.
- A team still on an older Terraform that predates `use_lockfile` would need the DynamoDB table
  back. Not a concern here given the pinned OpenTofu 1.12.
