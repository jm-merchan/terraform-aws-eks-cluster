output "nginx_load_balancer_hostname" {
  description = "Public DNS hostname of the NGINX NLB"
  value       = kubernetes_service.nginx.status[0].load_balancer[0].ingress[0].hostname
}

output "cluster_name" {
  description = "Name of the EKS cluster serving this app (read from eks-infra-vcs)"
  value       = local.cluster_name
}
