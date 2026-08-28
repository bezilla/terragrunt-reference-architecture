mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-00000000000000000" }
  }
}

variables {
  cluster_name    = "acme-prod-eks"
  node_group_name = "default"
  subnet_ids      = ["subnet-a", "subnet-b"]
}

run "imdsv2_enforced" {
  command = plan
  assert {
    condition     = aws_launch_template.node.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 (http_tokens=required) must be enforced."
  }
}

run "root_volume_encrypted" {
  command = plan
  assert {
    condition     = tobool(aws_launch_template.node.block_device_mappings[0].ebs[0].encrypted) == true
    error_message = "Root volume must be encrypted."
  }
}

run "no_taints_by_default" {
  command = plan
  assert {
    condition     = length(aws_eks_node_group.this.taint) == 0
    error_message = "No taints unless specified."
  }
}

run "taints_applied" {
  command = plan
  variables {
    taints = [{ key = "dedicated", value = "gpu", effect = "NO_SCHEDULE" }]
  }
  assert {
    condition     = length(aws_eks_node_group.this.taint) == 1
    error_message = "Taint should be applied from the list."
  }
}
