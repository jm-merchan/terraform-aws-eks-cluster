variable "aws_region" {
  description = "AWS region (must match eks-infra-vcs)"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Team or individual that owns this deployment"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost centre for billing attribution"
  type        = string
  default     = "CC-DEV1"
}

variable "project" {
  description = "Project identifier"
  type        = string
  default     = "eks-app"
}

variable "tfc_organization" {
  description = "HCP Terraform organisation name"
  type        = string
  default     = "jose-merchan"
}

variable "infra_workspace" {
  description = "Name of the upstream infrastructure workspace to read outputs from"
  type        = string
  default     = "eks-infra-vcs"
}
