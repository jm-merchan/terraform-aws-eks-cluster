output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (private)"
  value       = module.eks_cluster.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.eks_cluster.vpc_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for secrets encryption"
  value       = module.eks_cluster.kms_key_arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks_cluster.oidc_provider_arn
}

output "nginx_load_balancer_hostname" {
  description = "Public DNS hostname of the NGINX NLB"
  value       = kubernetes_service.nginx.status[0].load_balancer[0].ingress[0].hostname
}

output "nginx_url" {
  description = "Full HTTP URL of the NGINX test app — open this in a browser"
  value       = "http://${kubernetes_service.nginx.status[0].load_balancer[0].ingress[0].hostname}"
}

output "kubeconfig_command" {
  description = "Command to update your local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}
