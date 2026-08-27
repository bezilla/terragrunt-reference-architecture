terraform {
  required_version = "~> 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # CloudFront certificates must be issued in us-east-1. The caller passes an aliased provider
      # as aws.us_east_1; this module never assumes the default provider's region.
      configuration_aliases = [aws.us_east_1]
    }
  }
}
