variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "allowed_api_cidr" {
  description = "CIDR that is allowed to reach the public Kubernetes API endpoint (e.g. your corporate egress IP)"
  type        = string

  validation {
    condition     = var.allowed_api_cidr != "0.0.0.0/0"
    error_message = "Do not allow 0.0.0.0/0 to reach the API server — use a specific CIDR."
  }
}
