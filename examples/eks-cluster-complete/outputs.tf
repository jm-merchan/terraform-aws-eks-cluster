output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks_cluster.cluster_version
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.eks_cluster.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.eks_cluster.private_subnet_ids
}

output "kms_key_arn" {
  description = "KMS key ARN used for secrets encryption"
  value       = module.eks_cluster.kms_key_arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — use in IRSA IAM trust policies"
  value       = module.eks_cluster.oidc_provider_arn
}

# Convenience: kubeconfig update command
output "kubeconfig_command" {
  description = "AWS CLI command to update your local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}
