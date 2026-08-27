output "group_names" {
  description = "Names of the managed IAM groups."
  value       = [for g in aws_iam_group.this : g.name]
}

output "user_names" {
  description = "Names of the managed IAM users."
  value       = [for u in aws_iam_user.this : u.name]
}

output "irsa_role_arns" {
  description = "ARNs of the created IRSA roles, keyed by role name."
  value       = { for k, r in aws_iam_role.irsa : k => r.arn }
}
