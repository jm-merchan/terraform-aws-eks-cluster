output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks_cluster.cluster_version
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks_cluster.oidc_provider_arn
}

output "oidc_provider" {
  description = "OIDC provider URL (without https://) for IRSA conditions"
  value       = module.eks_cluster.oidc_provider
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for EKS secrets encryption"
  value       = module.eks_cluster.kms_key_arn
  sensitive   = true
}

output "aws_region" {
  description = "AWS region where the cluster is deployed"
  value       = var.aws_region
}
