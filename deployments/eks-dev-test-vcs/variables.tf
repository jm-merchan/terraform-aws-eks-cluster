variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "owner" {
  description = "Team or individual that owns this deployment"
  type        = string
  default     = "jose-merchan"
}

variable "cost_center" {
  description = "Cost centre for billing attribution"
  type        = string
  default     = "sandbox"
}

variable "project" {
  description = "Project identifier"
  type        = string
  default     = "eks-dev-test"
}

variable "cluster_suffix" {
  description = "Short suffix appended to the cluster name to disambiguate parallel deployments (e.g. 'cli', 'vcs')"
  type        = string
  default     = ""
}
