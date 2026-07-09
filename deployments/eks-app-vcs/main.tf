################################################################################
# Remote state outputs from eks-infra-vcs
# tfe_outputs reads the workspace outputs directly via the TFE provider.
# No local state file needed — fully dynamic.
################################################################################

data "tfe_outputs" "infra" {
  organization = var.tfc_organization
  workspace    = var.infra_workspace
}

locals {
  cluster_name   = data.tfe_outputs.infra.values.cluster_name
  cluster_ep     = data.tfe_outputs.infra.values.cluster_endpoint
  cluster_ca     = data.tfe_outputs.infra.values.cluster_certificate_authority_data
  aws_region     = data.tfe_outputs.infra.values.aws_region
}

################################################################################
# Providers
################################################################################

provider "aws" {
  region = local.aws_region
}

provider "kubernetes" {
  host                   = local.cluster_ep
  cluster_ca_certificate = base64decode(local.cluster_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", local.cluster_name,
      "--region", local.aws_region,
    ]
  }
}

################################################################################
# Application namespace
################################################################################

resource "kubernetes_namespace" "app" {
  metadata {
    name = "nginx-app"
    labels = {
      environment = var.environment
      owner       = var.owner
      project     = var.project
    }
  }
}

################################################################################
# ConfigMap — custom NGINX welcome page
################################################################################

resource "kubernetes_config_map" "nginx_html" {
  metadata {
    name      = "nginx-html"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    "index.html" = <<-HTML
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <title>EKS App — ${var.project}</title>
          <style>
            *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
            body {
              min-height: 100vh;
              display: flex; align-items: center; justify-content: center;
              font-family: 'IBM Plex Sans', 'Segoe UI', system-ui, sans-serif;
              background: linear-gradient(135deg, #0f0c29, #1a1a6e, #12003d);
              background-size: 400% 400%;
              animation: gradientShift 12s ease infinite;
              color: #f4f4f4; padding: 2rem;
            }
            @keyframes gradientShift {
              0%   { background-position: 0% 50%; }
              50%  { background-position: 100% 50%; }
              100% { background-position: 0% 50%; }
            }
            .card {
              background: rgba(255,255,255,0.07);
              backdrop-filter: blur(18px);
              border: 1px solid rgba(255,255,255,0.15);
              border-radius: 20px; padding: 3rem 3.5rem;
              max-width: 560px; width: 100%;
              box-shadow: 0 25px 60px rgba(0,0,0,0.5); text-align: center;
            }
            .badge {
              display: inline-flex; align-items: center; gap: 0.5rem;
              background: rgba(66,220,130,0.15); border: 1px solid rgba(66,220,130,0.4);
              color: #42dc82; border-radius: 999px; padding: 0.4rem 1.1rem;
              font-size: 0.85rem; font-weight: 600; letter-spacing: 0.04em;
              text-transform: uppercase; margin-bottom: 1.6rem;
            }
            .badge::before {
              content: ''; width: 8px; height: 8px; border-radius: 50%;
              background: #42dc82; animation: pulse 1.8s ease-in-out infinite;
            }
            @keyframes pulse {
              0%, 100% { opacity: 1; transform: scale(1); }
              50%       { opacity: 0.4; transform: scale(1.4); }
            }
            h1 {
              font-size: 2rem; font-weight: 700; line-height: 1.2; margin-bottom: 0.5rem;
              background: linear-gradient(90deg, #ffffff, #a8c8ff);
              -webkit-background-clip: text; -webkit-text-fill-color: transparent;
              background-clip: text;
            }
            .subtitle { color: rgba(255,255,255,0.5); font-size: 0.95rem; margin-bottom: 2.2rem; }
            .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 2rem; }
            .info-item {
              background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1);
              border-radius: 12px; padding: 0.9rem 1rem; text-align: left;
            }
            .info-label {
              font-size: 0.72rem; font-weight: 600; letter-spacing: 0.08em;
              text-transform: uppercase; color: rgba(255,255,255,0.4); margin-bottom: 0.3rem;
            }
            .info-value { font-size: 0.95rem; font-weight: 600; color: #ffffff; }
            hr { border: none; border-top: 1px solid rgba(255,255,255,0.1); margin: 0 0 1.5rem; }
            .footer { font-size: 0.78rem; color: rgba(255,255,255,0.35); line-height: 1.6; }
            .footer strong { color: #78a9ff; font-weight: 600; }
            .provider-logo {
              display: inline-block; margin-top: 1rem;
              background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1);
              border-radius: 8px; padding: 0.35rem 0.9rem;
              font-size: 0.75rem; font-weight: 700; letter-spacing: 0.1em;
              color: #78a9ff; text-transform: uppercase;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="badge">App Deployed</div>
            <h1>NGINX App is Running</h1>
            <p class="subtitle">Deployed by eks-app-vcs workspace</p>
            <div class="info-grid">
              <div class="info-item">
                <div class="info-label">Cluster</div>
                <div class="info-value">${var.infra_workspace}</div>
              </div>
              <div class="info-item">
                <div class="info-label">Environment</div>
                <div class="info-value">${var.environment}</div>
              </div>
              <div class="info-item">
                <div class="info-label">Project</div>
                <div class="info-value">${var.project}</div>
              </div>
              <div class="info-item">
                <div class="info-label">Region</div>
                <div class="info-value">${var.aws_region}</div>
              </div>
            </div>
            <hr />
            <div class="footer">
              Generated by <strong>Bob</strong><br/>
              IBM watsonx AI Assistant
              <div class="provider-logo">IBM &#x2022; watsonx</div>
            </div>
          </div>
        </body>
      </html>
    HTML
  }
}

################################################################################
# NGINX Deployment
################################################################################

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app         = "nginx"
      environment = var.environment
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = {
          app         = "nginx"
          environment = var.environment
        }
      }

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
          config_map {
            name = kubernetes_config_map.nginx_html.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.app]
}

################################################################################
# NLB Service — internet-facing
################################################################################

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.app.metadata[0].name
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
