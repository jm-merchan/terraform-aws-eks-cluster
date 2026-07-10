provider "aws" {
  region = var.aws_region
}

################################################################################
# AMI — latest approved Ubuntu 24.04 base image from the internal AMI registry.
# Two lookups: amd64 (x86_64 instances) and arm64 (Graviton instances).
# Use data.aws_ami.hc_base_ubuntu["amd64"].id or ["arm64"].id in node_groups.
################################################################################

data "aws_ami" "hc_base_ubuntu" {
  for_each = toset(["amd64", "arm64"])

  filter {
    name   = "name"
    values = [format("hc-base-ubuntu-2404-%s-*", each.value)]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  most_recent = true
  owners      = ["888995627335"] # ami-prod account
}

################################################################################
# EKS Cluster — private registry module (infrastructure only, no app workloads)
################################################################################

module "eks_cluster" {
  source  = "app.terraform.io/jose-merchan/eks-cluster/aws"
  version = "0.0.4"

  # Mandatory tags
  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project

  # Cluster
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Public endpoint — remote runner needs API server access.
  # Restrict to your organisation's egress IP(s) or the HCP Terraform runner CIDR.
  # See: https://developer.hashicorp.com/terraform/cloud-docs/architectural-details/ip-ranges
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.api_allowed_cidrs
  enable_irsa                  = true
  log_retention_days           = 90

  # Node group — 3 nodes so Vault HA Raft (3 replicas) can schedule.
  # Uses the latest approved Ubuntu 24.04 x86_64 AMI from the internal registry.
  #
  # ⚠️  AWS constraint: when ami_id is set, ami_type/ami_release_version are
  #     rejected by the EKS API. The module omits them automatically.
  # ⚠️  EKS does NOT inject bootstrap user data with a custom AMI. The full
  #     AL2023 NodeConfig bootstrap document is provided via pre_bootstrap_user_data
  #     so the node can call the EKS API and join the cluster.
  #     Ref: https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html
  node_groups = {
    dev = {
      instance_types             = ["t3.medium"] # x86_64 — use amd64 AMI
      capacity_type              = "ON_DEMAND"
      min_size                   = 2
      max_size                   = 5
      desired_size               = 3
      disk_size_gb               = 50
      ami_id                     = data.aws_ami.hc_base_ubuntu["amd64"].id
      enable_bootstrap_user_data = true
      # Full bootstrap document required — EKS will not merge user data.
      # Cluster outputs are referenced so values are always in sync.
      pre_bootstrap_user_data = templatefile("${path.module}/bootstrap-userdata.tpl", {
        cluster_name     = var.cluster_name
        api_endpoint     = module.eks_cluster.cluster_endpoint
        cluster_ca       = module.eks_cluster.cluster_certificate_authority_data
        service_cidr     = "10.100.0.0/16" # must match cluster service CIDR
      })
    }
  }

  # VPC — eu-central-1 has 3 AZs; using 10.1.x range to avoid collision
  availability_zones     = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  vpc_cidr               = "10.1.0.0/16"
  private_subnet_cidrs   = ["10.1.0.0/19", "10.1.32.0/19", "10.1.64.0/19"]
  public_subnet_cidrs    = ["10.1.128.0/20", "10.1.144.0/20", "10.1.160.0/20"]
  enable_internet_access = true
  single_nat_gateway     = true

  # aws-ebs-csi-driver excluded here — installed below as a standalone
  # aws_eks_addon so that the IRSA role ARN can be wired after cluster creation.
  addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true, before_compute = true }
  }
}

################################################################################
# IRSA — IAM role for the EBS CSI driver service account
################################################################################

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks_cluster.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks_cluster.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks_cluster.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name_prefix        = "${var.cluster_name}-ebs-csi-"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json

  tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# AmazonEBSCSIDriverPolicyV2 is the current managed policy (V1 is deprecated)
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicyV2"
}

# KMS permissions — required because node EBS volumes are encrypted with the cluster KMS key.
# Grant actions are in a separate statement with the kms:GrantIsForAWSResource condition
# as required by the AWS EBS CSI driver documentation.
resource "aws_iam_policy" "ebs_csi_kms" {
  name_prefix = "${var.cluster_name}-ebs-csi-kms-"
  description = "Allow EBS CSI driver to use the cluster KMS key for volume encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
        ]
        Resource = [module.eks_cluster.kms_key_arn]
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = [module.eks_cluster.kms_key_arn]
      }
    ]
  })

  tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_kms" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = aws_iam_policy.ebs_csi_kms.arn
}

################################################################################
# EBS CSI Driver addon — installed after IRSA role is ready
################################################################################

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  # Static version string — cluster_version is computed and unknown at plan time
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = module.eks_cluster.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  preserve                    = true

  namespace_config {
    namespace = "kube-system"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  depends_on = [
    module.eks_cluster,
    aws_iam_role_policy_attachment.ebs_csi,
    aws_iam_role_policy_attachment.ebs_csi_kms,
  ]
}
