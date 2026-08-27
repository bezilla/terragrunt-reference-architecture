output "database_names" {
  description = "Names of the created logical databases."
  value       = keys(var.databases)
}

output "password_parameter_names" {
  description = "SSM parameter names holding each role's generated password."
  value       = { for k, p in aws_ssm_parameter.password : k => p.name }
}
