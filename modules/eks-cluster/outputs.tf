################################################################################
# Networking
################################################################################

output "vpc_id" {
  description = "ID of the VPC used by the cluster (created or pre-existing)"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets used for cluster nodes"
  value       = local.subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (empty when internet access is disabled or an existing VPC is supplied)"
  value       = local.create_vpc ? module.vpc[0].public_subnets : []
}

################################################################################
# EKS Cluster
################################################################################

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_primary_security_group_id" {
  description = "EKS-managed primary security group ID"
  value       = module.eks.cluster_primary_security_group_id
}

output "cluster_security_group_id" {
  description = "Security group ID created by this module for the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID shared by all node groups"
  value       = module.eks.node_security_group_id
}

################################################################################
# KMS
################################################################################

output "kms_key_arn" {
  description = "ARN of the KMS key used for secrets encryption"
  value       = module.eks.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for secrets encryption"
  value       = module.eks.kms_key_id
}

################################################################################
# IRSA
################################################################################

output "oidc_provider" {
  description = "OIDC provider URL (without https://) — use as the issuer in IAM trust policies"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider — required when creating IRSA IAM roles"
  value       = module.eks.oidc_provider_arn
}

################################################################################
# IAM
################################################################################

output "cluster_iam_role_arn" {
  description = "IAM role ARN assumed by the EKS control plane"
  value       = module.eks.cluster_iam_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for the EBS CSI driver (IRSA). Empty string if create_ebs_csi_irsa_role = false"
  value       = var.enable_irsa && var.create_ebs_csi_irsa_role ? aws_iam_role.ebs_csi_driver[0].arn : ""
}

################################################################################
# Node Groups
################################################################################

output "eks_managed_node_groups" {
  description = "Attributes of all EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "Auto Scaling Group names for each managed node group"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

################################################################################
# Logging
################################################################################

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for EKS control-plane logs"
  value       = module.eks.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN for EKS control-plane logs"
  value       = module.eks.cloudwatch_log_group_arn
}
