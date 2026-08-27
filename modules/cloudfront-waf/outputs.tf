output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name (for DNS aliasing)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "web_acl_arn" {
  description = "ARN of the WAFv2 web ACL."
  value       = aws_wafv2_web_acl.this.arn
}
