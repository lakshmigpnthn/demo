# Environment Outputs

#------------------------------------------------------------------------------
# VPC Outputs
#------------------------------------------------------------------------------
output "gateway_vpc_id" {
  description = "ID of the Gateway VPC"
  value       = module.vpc_gateway.vpc_id
}

output "gateway_vpc_cidr" {
  description = "CIDR block of the Gateway VPC"
  value       = module.vpc_gateway.vpc_cidr
}

output "backend_vpc_id" {
  description = "ID of the Backend VPC"
  value       = module.vpc_backend.vpc_id
}

output "backend_vpc_cidr" {
  description = "CIDR block of the Backend VPC"
  value       = module.vpc_backend.vpc_cidr
}

output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = module.vpc_peering.peering_connection_id
}

#------------------------------------------------------------------------------
# EKS Gateway Outputs
#------------------------------------------------------------------------------
output "eks_gateway_cluster_name" {
  description = "Name of the Gateway EKS cluster"
  value       = module.eks_gateway.cluster_name
}

output "eks_gateway_cluster_endpoint" {
  description = "Endpoint for the Gateway EKS cluster"
  value       = module.eks_gateway.cluster_endpoint
}

output "eks_gateway_cluster_arn" {
  description = "ARN of the Gateway EKS cluster"
  value       = module.eks_gateway.cluster_arn
}

output "eks_gateway_node_security_group_id" {
  description = "Security group ID of Gateway EKS nodes"
  value       = module.eks_gateway.node_security_group_id
}

#------------------------------------------------------------------------------
# EKS Backend Outputs
#------------------------------------------------------------------------------
output "eks_backend_cluster_name" {
  description = "Name of the Backend EKS cluster"
  value       = module.eks_backend.cluster_name
}

output "eks_backend_cluster_endpoint" {
  description = "Endpoint for the Backend EKS cluster"
  value       = module.eks_backend.cluster_endpoint
}

output "eks_backend_cluster_arn" {
  description = "ARN of the Backend EKS cluster"
  value       = module.eks_backend.cluster_arn
}

output "eks_backend_node_security_group_id" {
  description = "Security group ID of Backend EKS nodes"
  value       = module.eks_backend.node_security_group_id
}

#------------------------------------------------------------------------------
# Security Outputs
#------------------------------------------------------------------------------
output "gateway_alb_security_group_id" {
  description = "Security group ID for the Gateway ALB"
  value       = module.security_groups.gateway_alb_security_group_id
}

#------------------------------------------------------------------------------
# CI/CD Outputs - COMMENTED OUT (No IAM tag role access)
#------------------------------------------------------------------------------
# output "github_actions_role_arn" {
#   description = "ARN of the IAM role for GitHub Actions"
#   value       = var.enable_github_oidc ? aws_iam_role.github_actions[0].arn : null
# }

#------------------------------------------------------------------------------
# Kubeconfig Commands
#------------------------------------------------------------------------------
output "configure_kubectl_gateway" {
  description = "Command to configure kubectl for Gateway cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks_gateway.cluster_name} --region ${var.aws_region} --alias eks-gateway"
}

output "configure_kubectl_backend" {
  description = "Command to configure kubectl for Backend cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks_backend.cluster_name} --region ${var.aws_region} --alias eks-backend"
}
