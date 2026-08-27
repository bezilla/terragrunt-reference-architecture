# Unit tests using the OpenTofu native test framework with a mocked AWS provider — they run with
# no credentials and no real API calls, exercising the module's logic and conditionals.

mock_provider "aws" {
  # Give computed attributes realistic shapes so provider-side validation passes without any API.
  mock_resource "aws_db_proxy_default_target_group" {
    defaults = {
      name = "default"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }
  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "aws_rds_cluster" {
    defaults = {
      id = "acme-mock-cluster"
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-west-2:123456789012:secret:rds!cluster-mock"
        kms_key_id    = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
        secret_status = "active"
      }]
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  cluster_identifier     = "acme-prod-core"
  engine_version         = "16.4"
  subnet_group_name      = "acme-prod-db"
  vpc_security_group_ids = ["sg-0123456789abcdef0"]
}

run "creates_expected_instance_count" {
  command = plan

  variables {
    instance_count = 3
  }

  assert {
    condition     = length(aws_rds_cluster_instance.this) == 3
    error_message = "Expected 3 cluster instances."
  }

  assert {
    condition     = aws_rds_cluster.this.storage_encrypted == true
    error_message = "Storage encryption must be enabled."
  }

  assert {
    condition     = aws_rds_cluster.this.manage_master_user_password == true
    error_message = "Master password must be managed by RDS/Secrets Manager."
  }
}

run "proxy_disabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_db_proxy.this) == 0
    error_message = "RDS Proxy should not be created unless create_proxy = true."
  }
}

run "proxy_created_when_enabled" {
  command = plan

  variables {
    create_proxy = true
  }

  assert {
    condition     = length(aws_db_proxy.this) == 1
    error_message = "RDS Proxy should be created when create_proxy = true."
  }
}
