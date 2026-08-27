output "role_arn" {
  description = "ARN of the role GitHub Actions assumes (the value for role-to-assume in the workflow)."
  value       = aws_iam_role.github.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider."
  value       = local.provider_arn
}
