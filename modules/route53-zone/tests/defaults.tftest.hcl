mock_provider "aws" {}

variables {
  zone_name = "example.com"
}

run "public_zone_has_no_vpc_association" {
  command = plan
  assert {
    condition     = length(aws_route53_zone.this.vpc) == 0
    error_message = "A public zone must not have a VPC association."
  }
}

run "private_zone_associates_vpc" {
  command = plan
  variables {
    private_zone = true
    vpc_id       = "vpc-abc123"
  }
  assert {
    condition     = length(aws_route53_zone.this.vpc) == 1
    error_message = "A private zone must associate the given VPC."
  }
}

run "records_created_from_map" {
  command = plan
  variables {
    records = {
      www  = { name = "www.example.com", type = "CNAME", records = ["example.com"] }
      apex = { name = "example.com", type = "A", ttl = 60, records = ["203.0.113.10"] }
    }
  }
  assert {
    condition     = length(aws_route53_record.this) == 2
    error_message = "Two records expected from the map."
  }
}
