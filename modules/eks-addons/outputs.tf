output "addon_versions" {
  description = "Resolved version of each installed add-on."
  value       = { for name, addon in aws_eks_addon.this : name => addon.addon_version }
}
