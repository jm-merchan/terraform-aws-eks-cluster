# Unit tests — plan mode only, no real AWS resources created.
# Validates default variable behaviour and locals logic.
# Mock providers are used so no AWS credentials are required.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDATEST"
    }
  }
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn    = "arn:aws:iam::123456789012:role/test-role"
      issuer_id     = "AROATEST"
      issuer_name   = "test-role"
      session_name  = ""
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
}
mock_provider "tls" {}
mock_provider "time" {}

variables {
  # Mandatory tags
  environment = "dev"
  owner       = "platform-team"
  cost_center = "CC-TEST"
  project     = "unit-test"

  # Minimal cluster config
  cluster_name = "unit-test-cluster"

  # Single node group with explicit values
  node_groups = {
    default = {
      instance_types = ["m6i.large"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      disk_size_gb   = 50
    }
  }
}

# ── New VPC path (default — vpc_id = null) ──────────────────────────────────

run "creates_vpc_when_no_vpc_id_given" {
  command = plan

  assert {
    condition     = length(module.vpc) == 1
    error_message = "A VPC module instance should be created when vpc_id is not provided"
  }
}

run "does_not_create_vpc_when_vpc_id_given" {
  command = plan

  variables {
    vpc_id     = "vpc-0abc123def456789"
    subnet_ids = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]
  }

  assert {
    condition     = length(module.vpc) == 0
    error_message = "No VPC module should be created when an existing vpc_id is provided"
  }
}

# ── Cluster name ─────────────────────────────────────────────────────────────

run "cluster_name_propagated" {
  command = plan

  assert {
    condition     = module.eks.cluster_name == "unit-test-cluster"
    error_message = "cluster_name must be passed through to the eks sub-module"
  }
}

# ── Mandatory tags ────────────────────────────────────────────────────────────

run "mandatory_tags_present" {
  command = plan

  assert {
    condition     = local.common_tags["Environment"] == "dev"
    error_message = "Environment tag must be set from var.environment"
  }

  assert {
    condition     = local.common_tags["Owner"] == "platform-team"
    error_message = "Owner tag must be set from var.owner"
  }

  assert {
    condition     = local.common_tags["CostCenter"] == "CC-TEST"
    error_message = "CostCenter tag must be set from var.cost_center"
  }

  assert {
    condition     = local.common_tags["Project"] == "unit-test"
    error_message = "Project tag must be set from var.project"
  }
}
