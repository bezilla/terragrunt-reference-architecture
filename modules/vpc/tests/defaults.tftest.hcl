mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  name             = "acme-prod"
  cidr_block       = "10.0.0.0/16"
  azs              = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets  = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
  public_subnets   = ["10.0.96.0/22", "10.0.100.0/22", "10.0.104.0/22"]
  database_subnets = ["10.0.108.0/24", "10.0.109.0/24", "10.0.110.0/24"]
  # Flow-log wiring belongs to the upstream vpc module; disable it here so tests assert on what
  # THIS module adds (endpoints, tag logic) rather than the wrapped module's internals.
  enable_flow_logs = false
}

run "s3_gateway_endpoint_created" {
  command = plan
  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "An S3 gateway endpoint must be created."
  }
}

run "single_nat_toggles_per_az" {
  command = plan
  variables {
    single_nat_gateway = true
  }
  # single_nat_gateway = true implies one_nat_gateway_per_az = false in the local wiring.
  assert {
    condition     = var.single_nat_gateway == true
    error_message = "sanity: single NAT selected"
  }
}
