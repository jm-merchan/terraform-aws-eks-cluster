################################################################################
# Required — Mandatory tags (security baseline)
################################################################################

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Team or individual that owns this resource"
  type        = string
}

variable "cost_center" {
  description = "Cost centre code for billing attribution"
  type        = string
}

variable "project" {
  description = "Project name for resource grouping"
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to merge with the mandatory tag set"
  type        = map(string)
  default     = {}
}

################################################################################
# EKS Cluster
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster (e.g. '1.33')"
  type        = string
  default     = "1.33"
}

variable "endpoint_public_access" {
  description = "Enable the public Kubernetes API server endpoint. When false the cluster is fully private"
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "List of CIDRs that may reach the public API endpoint. Only relevant when endpoint_public_access = true"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.endpoint_public_access_cidrs :
      cidr != "0.0.0.0/0"
    ])
    error_message = "Restrict API server access to specific CIDR ranges — do not allow 0.0.0.0/0."
  }
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (OIDC provider)"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch control-plane logs"
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "Log retention must be at least 90 days to meet the security baseline."
  }
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the caller identity cluster-admin access via an EKS access entry"
  type        = bool
  default     = true
}

variable "access_entries" {
  description = "Map of additional IAM access entries to add to the cluster"
  type = map(object({
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

################################################################################
# Node Groups / Node Pools
################################################################################

variable "node_groups" {
  description = <<-EOT
    Map of EKS managed node group definitions. Each key becomes the node group name.
    Example:
      node_groups = {
        general = {
          instance_types = ["m6i.large"]
          min_size       = 1
          max_size       = 5
          desired_size   = 2
          disk_size_gb   = 50
        }
      }
  EOT
  type = map(object({
    instance_types = optional(list(string), ["m6i.large"])
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = optional(number, 1)
    max_size       = optional(number, 3)
    desired_size   = optional(number, 2)
    disk_size_gb   = optional(number, 50)
    labels         = optional(map(string), {})
    taints = optional(map(object({
      key    = string
      value  = optional(string)
      effect = string
    })), {})
    tags = optional(map(string), {})
  }))
  default = {
    default = {
      instance_types = ["m6i.large"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      disk_size_gb   = 50
    }
  }

  validation {
    condition = alltrue([
      for ng in values(var.node_groups) : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size
    ])
    error_message = "For each node group: min_size <= desired_size <= max_size."
  }

  validation {
    condition = alltrue([
      for ng in values(var.node_groups) : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)
    ])
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

################################################################################
# EKS Add-ons
################################################################################

variable "create_ebs_csi_irsa_role" {
  description = "Create an IAM Role for the EBS CSI driver using IRSA. Requires enable_irsa = true. The role gets AmazonEBSCSIDriverPolicyV2 attached automatically."
  type        = bool
  default     = true
}

variable "addons" {
  description = "Map of EKS add-on configurations. Defaults to the four core add-ons"
  type = map(object({
    name                        = optional(string)
    before_compute              = optional(bool, false)
    most_recent                 = optional(bool, true)
    addon_version               = optional(string)
    configuration_values        = optional(string)
    preserve                    = optional(bool, true)
    resolve_conflicts_on_create = optional(string, "NONE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }), {})
    tags = optional(map(string), {})
  }))
  default = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}

################################################################################
# Networking — VPC creation (used when vpc_id is NOT provided)
################################################################################

variable "vpc_id" {
  description = "ID of an existing VPC to deploy the cluster into. When null, a new VPC is created"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of existing subnet IDs for cluster nodes. Required when vpc_id is provided; ignored when a new VPC is created"
  type        = list(string)
  default     = []

  validation {
    condition     = !(length(var.subnet_ids) > 0 && length(var.subnet_ids) < 2)
    error_message = "Provide at least 2 subnet IDs across different AZs for high availability."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC (only used when vpc_id is null)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for subnet placement (only used when vpc_id is null)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (only used when vpc_id is null). Must have one entry per availability zone"
  type        = list(string)
  default     = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (only used when vpc_id = null and enable_internet_access = true)"
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
}

variable "enable_internet_access" {
  description = "Create an Internet Gateway and NAT Gateways to provide internet access from private subnets. Only used when vpc_id is null"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Provision a single shared NAT Gateway instead of one per AZ. Reduces cost but eliminates AZ-level NAT redundancy. Only used when vpc_id is null"
  type        = bool
  default     = false
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets created by the module"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets created by the module"
  type        = map(string)
  default     = {}
}
