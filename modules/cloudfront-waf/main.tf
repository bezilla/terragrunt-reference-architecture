# CloudFront distribution fronted by the WAF web ACL.
#
# Multi-vendor edge (CloudFront + Fastly + Cloudflare) was a deliberate choice in the source
# system; this repo shows the CloudFront path and discusses the tradeoff in an ADR rather than
# shipping three CDNs. TLS is pinned to TLSv1.2_2021; HTTP is redirected to HTTPS.

locals {
  origin_id = "primary"
  use_oac   = var.origin_type == "s3"
}

resource "aws_cloudfront_origin_access_control" "this" {
  count = local.use_oac ? 1 : 0

  name                              = var.name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Access logging is opt-in: enabling it requires an S3 bucket with log-delivery ACLs enabled,
# which is the caller's concern (and conflicts with BucketOwnerEnforced buckets). When no bucket
# is supplied, logging is intentionally off.
#trivy:ignore:AVD-AWS-0010
resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = var.name
  aliases         = var.aliases
  web_acl_id      = aws_wafv2_web_acl.this.arn
  price_class     = "PriceClass_100"

  origin {
    origin_id                = local.origin_id
    domain_name              = var.origin_domain_name
    origin_access_control_id = local.use_oac ? aws_cloudfront_origin_access_control.this[0].id : null

    dynamic "custom_origin_config" {
      for_each = local.use_oac ? [] : [1]
      content {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    # AWS managed CachingOptimized policy.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  dynamic "logging_config" {
    for_each = var.log_bucket_domain_name == null ? [] : [1]
    content {
      bucket          = var.log_bucket_domain_name
      include_cookies = false
      prefix          = "${var.name}/"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? "TLSv1" : "TLSv1.2_2021"
  }

  tags = var.tags
}
