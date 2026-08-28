mock_provider "aws" {}
mock_provider "postgresql" {}
mock_provider "random" {}

variables {
  databases = {
    orders = { owner_role = "orders_app" }
    users  = { owner_role = "users_app" }
  }
}

run "one_role_db_and_secret_per_database" {
  command = plan
  assert {
    condition     = length(postgresql_role.owner) == 2 && length(postgresql_database.this) == 2
    error_message = "A role and database per input entry."
  }
  assert {
    condition     = length(aws_ssm_parameter.password) == 2
    error_message = "A generated password stored in SSM per database."
  }
  assert {
    condition     = alltrue([for p in aws_ssm_parameter.password : p.type == "SecureString"])
    error_message = "Passwords must be stored as SecureString."
  }
}
