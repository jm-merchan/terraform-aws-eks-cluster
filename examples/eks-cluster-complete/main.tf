################################################################################
# Complete example — creates a new VPC and a multi-node-group EKS cluster
################################################################################

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Point at your HCP Terraform org for remote state and private module access
  cloud {
    organization = "jose-merchan"
    workspaces {
      name = "eks-cluster-example"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "eks_cluster" {
  # Once published to the PMR, replace the local path with:
  #   source  = "app.terraform.io/jose-merchan/eks-cluster/aws"
  #   version = "~> 0.0"
  source = "../../modules/eks-cluster"

  # ── Mandatory tags ──────────────────────────────────────────────────────────
  environment = var.environment
  owner       = "platform-team"
  cost_center = "CC-1234"
  project     = "example"

  # ── Cluster ─────────────────────────────────────────────────────────────────
  cluster_name       = "${var.environment}-eks-demo"
  kubernetes_version = "1.33"

  # Public endpoint restricted to a known CIDR — never 0.0.0.0/0
  endpoint_public_access       = true
  endpoint_public_access_cidrs = [var.allowed_api_cidr]

  # IRSA enabled so workloads can use fine-grained IAM roles
  enable_irsa = true

  log_retention_days = 90

  # ── Node Groups ──────────────────────────────────────────────────────────────
  node_groups = {
    # Dedicated system node group (on-demand, small)
    system = {
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      disk_size_gb   = 50
      labels = {
        role = "system"
      }
    }

    # General workload node group (mix of on-demand and spot)
    workers = {
      instance_types = ["m6i.xlarge", "m6a.xlarge", "m5.xlarge"]
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 10
      desired_size   = 3
      disk_size_gb   = 100
      labels = {
        role = "worker"
      }
    }

    # GPU node group — disabled by default (desired_size = 0)
    gpu = {
      instance_types = ["g4dn.xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size       = 0
      max_size       = 4
      desired_size   = 0
      disk_size_gb   = 100
      labels = {
        role                          = "gpu"
        "nvidia.com/gpu.present"      = "true"
      }
      taints = {
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  # ── Networking — new VPC is created automatically ────────────────────────────
  availability_zones     = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  vpc_cidr               = "10.10.0.0/16"
  private_subnet_cidrs   = ["10.10.0.0/19", "10.10.32.0/19", "10.10.64.0/19"]
  public_subnet_cidrs    = ["10.10.128.0/20", "10.10.144.0/20", "10.10.160.0/20"]
  enable_internet_access = true
  single_nat_gateway     = var.environment != "prod" # Save cost in non-prod
}
