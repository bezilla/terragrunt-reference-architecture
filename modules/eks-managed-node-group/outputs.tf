output "node_group_arn" {
  description = "ARN of the managed node group."
  value       = aws_eks_node_group.this.arn
}

output "node_role_arn" {
  description = "ARN of the IAM role assumed by the nodes."
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the node IAM role (for attaching extra policies)."
  value       = aws_iam_role.node.name
}
