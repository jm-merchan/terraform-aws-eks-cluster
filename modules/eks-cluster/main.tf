################################################################################
# VPC — created only when var.vpc_id is NOT provided
################################################################################

################################################################################
# IAM Role for EBS CSI Driver (IRSA)
# Required so the addon can call EC2 APIs (CreateVolume, AttachVolume, etc.)
# See: https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
################################################################################

data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  count = var.enable_irsa && var.create_ebs_csi_irsa_role ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_irsa && var.create_ebs_csi_irsa_role ? 1 : 0

  name_prefix        = "${var.cluster_name}-ebs-csi-"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = var.enable_irsa && var.create_ebs_csi_irsa_role ? 1 : 0

  role       = aws_iam_role.ebs_csi_driver[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicyV2"
}

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
  create_kms_key    = true
  encryption_config = {
    resources = ["secrets"]
  }
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

      labels = merge(local.common_tags, cfg.labels)
      taints = cfg.taints

      tags = merge(local.common_tags, cfg.tags)
    }
  }

  # Cluster-wide EKS add-ons — inject IRSA role ARN into the EBS CSI driver addon
  addons = {
    for addon_key, addon_cfg in var.addons : addon_key => merge(
      addon_cfg,
      # If this is the EBS CSI driver and we created an IRSA role, inject the ARN automatically
      addon_key == "aws-ebs-csi-driver" && var.enable_irsa && var.create_ebs_csi_irsa_role ? {
        service_account_role_arn = aws_iam_role.ebs_csi_driver[0].arn
      } : {}
    )
  }

  tags = local.common_tags
}
