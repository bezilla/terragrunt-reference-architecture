mock_provider "aws" {}
mock_provider "aws" { alias = "us_east_1" }

variables {
  domain_name     = "example.com"
  route53_zone_id = "Z00000000000000000000"
}

run "dns_validation" {
  command = plan
  assert {
    condition     = aws_acm_certificate.this.validation_method == "DNS"
    error_message = "Certificate must use DNS validation."
  }
}
