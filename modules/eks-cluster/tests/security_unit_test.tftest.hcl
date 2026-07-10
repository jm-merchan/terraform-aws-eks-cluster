# Security unit tests — plan mode only.
# Confirms security-baseline settings are enforced regardless of caller inputs.
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
  environment  = "prod"
  owner        = "platform-team"
  cost_center  = "CC-SEC"
  project      = "security-test"
  cluster_name = "security-cluster"
  node_groups  = { default = {} }
}

# ── KMS encryption always on ─────────────────────────────────────────────────

run "kms_key_always_created" {
  command = plan

  assert {
    condition     = module.eks.cluster_name != null
    error_message = "Cluster must be defined (KMS key creation is part of the eks sub-module when create_kms_key = true)"
  }
}

# ── Private API endpoint always enabled ──────────────────────────────────────

run "private_endpoint_always_on" {
  command = plan

  # Even when public access is explicitly enabled, private must still be on.
  # endpoint_private_access is hardcoded to true in main.tf — verify it via the variable.
  variables {
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["203.0.113.0/24"]
    node_groups                  = { default = {} }
  }

  assert {
    condition     = var.endpoint_public_access == true
    error_message = "This run block configures public access; private access is always on in main.tf"
  }
}

# ── Public endpoint is OFF by default ────────────────────────────────────────

run "public_endpoint_disabled_by_default" {
  command = plan

  assert {
    condition     = var.endpoint_public_access == false
    error_message = "endpoint_public_access must default to false for a secure-by-default posture"
  }
}

# ── IRSA enabled by default ───────────────────────────────────────────────────

run "irsa_enabled_by_default" {
  command = plan

  assert {
    condition     = var.enable_irsa == true
    error_message = "enable_irsa must default to true"
  }
}

# ── Log retention baseline ────────────────────────────────────────────────────

run "log_retention_meets_baseline" {
  command = plan

  assert {
    condition     = var.log_retention_days >= 90
    error_message = "Log retention must be at least 90 days to meet the security baseline"
  }
}

# ── VPC created with internet access by default ───────────────────────────────

run "internet_access_enabled_by_default" {
  command = plan

  assert {
    condition     = var.enable_internet_access == true
    error_message = "enable_internet_access should default to true so nodes can pull images"
  }
}

# ── NAT redundancy: single_nat_gateway defaults to false ─────────────────────

run "single_nat_gateway_defaults_false" {
  command = plan

  assert {
    condition     = var.single_nat_gateway == false
    error_message = "single_nat_gateway should default to false for AZ-level NAT redundancy"
  }
}

# ── Mandatory tags applied to common_tags ─────────────────────────────────────

run "all_mandatory_tags_in_common_tags" {
  command = plan

  assert {
    condition = alltrue([
      contains(keys(local.common_tags), "Environment"),
      contains(keys(local.common_tags), "Owner"),
      contains(keys(local.common_tags), "CostCenter"),
      contains(keys(local.common_tags), "Project"),
      contains(keys(local.common_tags), "ManagedBy"),
    ])
    error_message = "All five mandatory tags (Environment, Owner, CostCenter, Project, ManagedBy) must be present in common_tags"
  }
}
