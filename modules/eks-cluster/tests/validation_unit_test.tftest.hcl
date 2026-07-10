# Validation unit tests — plan mode only.
# Verifies that variable validation rules reject invalid inputs.
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
  environment = "dev"
  owner       = "platform-team"
  cost_center = "CC-TEST"
  project     = "validation-test"
  cluster_name = "validation-cluster"
}

# ── environment validation ────────────────────────────────────────────────────

run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "production" # not in [dev, staging, prod]
  }

  expect_failures = [var.environment]
}

# ── endpoint_public_access_cidrs — must not allow 0.0.0.0/0 ─────────────────
# The validation rule was added to variables.tf to enforce this.

run "rejects_open_public_access_cidr" {
  command = plan

  variables {
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["0.0.0.0/0"]
    node_groups                  = { default = {} }
  }

  expect_failures = [var.endpoint_public_access_cidrs]
}

run "accepts_restricted_public_access_cidr" {
  command = plan

  variables {
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["203.0.113.0/24"]
    node_groups = {
      default = {}
    }
  }

  assert {
    condition     = length(var.endpoint_public_access_cidrs) == 1 && contains(var.endpoint_public_access_cidrs, "203.0.113.0/24")
    error_message = "A specific CIDR should be accepted for public endpoint access"
  }
}

# ── log_retention_days — must be >= 90 ───────────────────────────────────────

run "rejects_log_retention_below_90_days" {
  command = plan

  variables {
    log_retention_days = 30
    node_groups        = { default = {} }
  }

  expect_failures = [var.log_retention_days]
}

# ── node_groups size ordering: min <= desired <= max ─────────────────────────

run "rejects_desired_size_above_max" {
  command = plan

  variables {
    node_groups = {
      bad = {
        min_size     = 1
        desired_size = 10
        max_size     = 5 # desired > max — invalid
      }
    }
  }

  expect_failures = [var.node_groups]
}

run "rejects_invalid_capacity_type" {
  command = plan

  variables {
    node_groups = {
      bad = {
        capacity_type = "RESERVED" # not ON_DEMAND or SPOT
      }
    }
  }

  expect_failures = [var.node_groups]
}

# ── subnet_ids — at least 2 when provided ────────────────────────────────────

run "rejects_single_subnet_id" {
  command = plan

  variables {
    vpc_id     = "vpc-0abc123"
    subnet_ids = ["subnet-only-one"] # only 1 — invalid
    node_groups = { default = {} }
  }

  expect_failures = [var.subnet_ids]
}
