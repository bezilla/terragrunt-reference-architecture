terraform {
  required_version = "~> 1.8"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.40"
    }
  }
}
