################################################################################
# VPC — created only when var.vpc_id is NOT provided
################################################################################

module "vpc" {
  count  = local.create_vpc ? 1 : 0
  source = "app.terraform.io/jose-merchan/vpc/aws"

  # Pin to currently published version; bump once the module is tagged
  version = "~> 0.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.availability_zones

  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.enable_internet_access ? var.public_subnet_cidrs : []

  # NAT gateway provides outbound internet access from private subnets
  enable_nat_gateway = var.enable_internet_access
  single_nat_gateway = var.single_nat_gateway

  # Internet gateway is required when internet access is enabled
  create_igw = var.enable_internet_access

  # VPC flow logs — always enabled (security baseline)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
  flow_log_traffic_type                = "ALL"

  # DNS support required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required EKS tags so the AWS LBC / cluster can discover subnets
  private_subnet_tags = merge(
    {
      "kubernetes.io/role/internal-elb"             = "1"
      "kubernetes.io/cluster/${var.cluster_name}"   = "owned"
    },
    var.private_subnet_tags,
  )

  public_subnet_tags = merge(
    {
      "kubernetes.io/role/elb"                      = "1"
      "kubernetes.io/cluster/${var.cluster_name}"   = "owned"
    },
    var.public_subnet_tags,
  )

  tags = local.common_tags
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "app.terraform.io/jose-merchan/eks/aws"

  # Pin to currently published version; bump once the module is tagged
  version = "~> 0.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  # Control-plane API server endpoint access
  endpoint_private_access   = true
  endpoint_public_access    = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Secrets encryption using KMS — always on
  # encryption_config must be a list of objects per the upstream terraform-aws-modules/eks API
  create_kms_key    = true
  cluster_encryption_config = [{
    resources = ["secrets"]
  }]
  enable_kms_key_rotation = true

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = var.enable_irsa

  # Control-plane logging — always on (security baseline)
  enabled_log_types = [
    "audit",
    "api",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  # Give the Terraform caller cluster-admin by default (can be disabled)
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Additional access entries (e.g. CI/CD roles, other IAM users)
  access_entries = var.access_entries

  # Managed node groups — built from var.node_groups
  eks_managed_node_groups = {
    for name, cfg in var.node_groups : name => {
      min_size       = cfg.min_size
      max_size       = cfg.max_size
      desired_size   = cfg.desired_size
      instance_types = cfg.instance_types
      capacity_type  = cfg.capacity_type

      # Node disk encryption using the cluster KMS key is handled by the node
      # group launch template; encrypted = true enforces it at the EBS level.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = cfg.disk_size_gb
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Only pass Kubernetes scheduling labels — do NOT merge AWS billing tags into
      # node labels. AWS tags belong in the tags map only.
      labels = cfg.labels
      taints = cfg.taints

      tags = merge(local.common_tags, cfg.tags)
    }
  }

  # Cluster-wide EKS add-ons.
  # aws-ebs-csi-driver is intentionally excluded from the module default and must
  # be added by the caller AFTER creating an IRSA role, so that
  # service_account_role_arn can be wired at that layer.
  cluster_addons = var.addons

  tags = local.common_tags
}
