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
  default     = "eks-infra"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-infra-dev"
}
