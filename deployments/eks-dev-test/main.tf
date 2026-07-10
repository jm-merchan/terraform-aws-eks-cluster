################################################################################
# EKS Dev Test — VCS-driven workspace (eks-dev-test-vcs)
#
# Workspace:  eks-dev-test-vcs  (renamed from eks-dev-test)
# Theme:      Electric Blue — "VCS-driven / GitOps"
# VPC CIDR:   10.2.0.0/16 (avoids collision with eks-infra-vcs 10.1.x)
# Module:     app.terraform.io/jose-merchan/eks-cluster/aws ~> 0.0.12
################################################################################

terraform {
  required_version = ">= 1.5.7"

  cloud {
    organization = "jose-merchan"
    workspaces {
      name = "eks-dev-test-vcs"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

################################################################################
# EKS Cluster
################################################################################

module "eks_cluster" {
  source  = "app.terraform.io/jose-merchan/eks-cluster/aws"
  version = "~> 0.0.12"

  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project

  cluster_name       = "${var.project}-${var.environment}"
  kubernetes_version = var.kubernetes_version

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.api_allowed_cidrs
  enable_irsa                  = true
  log_retention_days           = 90

  node_groups = {
    dev = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 1
      max_size       = 3
      desired_size   = 1
      disk_size_gb   = 50
    }
  }

  # 10.2.x — does not collide with eks-infra-vcs (10.1.x) or eks-dev-test-cli (10.3.x)
  availability_zones     = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  vpc_cidr               = "10.2.0.0/16"
  private_subnet_cidrs   = ["10.2.0.0/19", "10.2.32.0/19", "10.2.64.0/19"]
  public_subnet_cidrs    = ["10.2.128.0/20", "10.2.144.0/20", "10.2.160.0/20"]
  enable_internet_access = true
  single_nat_gateway     = true

  addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true, before_compute = true }
  }
}

################################################################################
# IRSA — EBS CSI Driver
################################################################################

resource "aws_iam_role" "ebs_csi_driver" {
  name_prefix = "${var.project}-${var.environment}-ebs-csi-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks_cluster.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks_cluster.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${module.eks_cluster.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

resource "aws_iam_policy" "ebs_csi_driver_kms" {
  name_prefix = "${var.project}-${var.environment}-ebs-csi-kms-"
  description = "Allow EBS CSI driver to use the cluster KMS key for volume encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
        Resource = [module.eks_cluster.kms_key_arn]
        Condition = { Bool = { "kms:GrantIsForAWSResource" = "true" } }
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
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

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_kms" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = aws_iam_policy.ebs_csi_driver_kms.arn
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks_cluster.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi_driver.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
  preserve                    = false

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
    aws_iam_role_policy_attachment.ebs_csi_driver,
    aws_iam_role_policy_attachment.ebs_csi_driver_kms,
  ]
}

################################################################################
# StorageClass gp3 — required for EKS 1.21+ (not created automatically)
################################################################################

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

################################################################################
# Kubernetes provider
################################################################################

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name, "--region", var.aws_region]
  }
}

################################################################################
# NGINX test app — Electric Blue theme, workspace: eks-dev-test-vcs
################################################################################

resource "kubernetes_namespace" "test_app" {
  metadata {
    name = "test-app"
    labels = {
      environment = var.environment
      owner       = var.owner
      project     = var.project
    }
  }

  depends_on = [module.eks_cluster]
}

resource "kubernetes_config_map" "nginx_html" {
  metadata {
    name      = "nginx-html"
    namespace = kubernetes_namespace.test_app.metadata[0].name
  }

  data = {
    "index.html" = <<-HTML
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <title>eks-dev-test-vcs &mdash; ${var.project}</title>
          <style>
            *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
            body {
              min-height: 100vh;
              display: flex; align-items: center; justify-content: center;
              font-family: 'IBM Plex Mono', 'Fira Code', monospace;
              background: linear-gradient(135deg, #001d6e 0%, #0043ce 50%, #001d6e 100%);
              background-size: 300% 300%;
              animation: gradientShift 10s ease infinite;
              color: #f4f4f4;
              padding: 2rem;
            }
            @keyframes gradientShift {
              0%,100% { background-position: 0% 50%; }
              50%      { background-position: 100% 50%; }
            }
            .card {
              background: rgba(0,67,206,0.18);
              backdrop-filter: blur(20px);
              border: 1px solid rgba(100,180,255,0.3);
              border-radius: 16px;
              padding: 3rem 3.5rem;
              max-width: 580px; width: 100%;
              box-shadow: 0 0 60px rgba(0,67,206,0.4);
              text-align: center;
            }
            .workspace-tag {
              display: inline-block;
              background: rgba(100,180,255,0.15);
              border: 1px solid rgba(100,180,255,0.5);
              color: #78b4ff;
              border-radius: 6px;
              padding: 0.3rem 0.9rem;
              font-size: 0.78rem;
              font-weight: 700;
              letter-spacing: 0.12em;
              text-transform: uppercase;
              margin-bottom: 1.4rem;
            }
            .badge {
              display: inline-flex; align-items: center; gap: 0.5rem;
              background: rgba(0,196,255,0.15);
              border: 1px solid rgba(0,196,255,0.4);
              color: #00c4ff;
              border-radius: 999px;
              padding: 0.4rem 1.1rem;
              font-size: 0.82rem; font-weight: 700;
              letter-spacing: 0.06em; text-transform: uppercase;
              margin-bottom: 1.6rem;
            }
            .badge::before {
              content: '';
              width: 8px; height: 8px; border-radius: 50%;
              background: #00c4ff;
              animation: pulse 1.8s ease-in-out infinite;
            }
            @keyframes pulse {
              0%,100% { opacity:1; transform:scale(1); }
              50%      { opacity:0.3; transform:scale(1.5); }
            }
            h1 {
              font-size: 1.9rem; font-weight: 700; line-height: 1.2;
              margin-bottom: 0.4rem;
              background: linear-gradient(90deg, #ffffff, #78b4ff);
              -webkit-background-clip: text; -webkit-text-fill-color: transparent;
              background-clip: text;
            }
            .subtitle { color: rgba(255,255,255,0.5); font-size: 0.92rem; margin-bottom: 2rem; }
            .info-grid {
              display: grid; grid-template-columns: 1fr 1fr;
              gap: 0.9rem; margin-bottom: 2rem;
            }
            .info-item {
              background: rgba(255,255,255,0.06);
              border: 1px solid rgba(100,180,255,0.2);
              border-radius: 10px; padding: 0.85rem 1rem; text-align: left;
            }
            .info-label {
              font-size: 0.68rem; font-weight: 700; letter-spacing: 0.1em;
              text-transform: uppercase; color: rgba(120,180,255,0.7); margin-bottom: 0.25rem;
            }
            .info-value { font-size: 0.92rem; font-weight: 600; color: #ffffff; }
            hr { border: none; border-top: 1px solid rgba(100,180,255,0.15); margin: 0 0 1.4rem; }
            .footer { font-size: 0.76rem; color: rgba(255,255,255,0.35); line-height: 1.6; }
            .footer strong { color: #78b4ff; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="workspace-tag">&#128279; eks-dev-test-vcs</div>
            <div class="badge">VCS-Driven &middot; GitOps</div>
            <h1>VCS Workspace Live</h1>
            <p class="subtitle">Triggered automatically on every git push to main</p>
            <div class="info-grid">
              <div class="info-item">
                <div class="info-label">Workspace</div>
                <div class="info-value">eks-dev-test-vcs</div>
              </div>
              <div class="info-item">
                <div class="info-label">Deploy Mode</div>
                <div class="info-value">VCS / GitOps</div>
              </div>
              <div class="info-item">
                <div class="info-label">Environment</div>
                <div class="info-value">${var.environment}</div>
              </div>
              <div class="info-item">
                <div class="info-label">Region</div>
                <div class="info-value">${var.aws_region}</div>
              </div>
            </div>
            <hr />
            <div class="footer">
              Generated by <strong>Bob</strong> &mdash; IBM watsonx AI Assistant
            </div>
          </div>
        </body>
      </html>
    HTML
  }

  depends_on = [kubernetes_namespace.test_app]
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.test_app.metadata[0].name
    labels    = { app = "nginx", environment = var.environment }
  }

  spec {
    replicas = 2

    selector { match_labels = { app = "nginx" } }

    template {
      metadata { labels = { app = "nginx", environment = var.environment } }

      spec {
        container {
          name  = "nginx"
          image = "public.ecr.aws/nginx/nginx:1.27-alpine"

          port { container_port = 80 }

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "html"
          config_map { name = kubernetes_config_map.nginx_html.metadata[0].name }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.test_app]
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.test_app.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
    }
  }

  spec {
    selector = { app = "nginx" }
    type     = "LoadBalancer"
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.nginx]
}
