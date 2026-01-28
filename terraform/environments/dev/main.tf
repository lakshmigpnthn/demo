# Sentinel Infrastructure - Development Environment
# This configuration deploys two isolated VPCs with EKS clusters and VPC peering

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Tags commented out - no IAM tag role access
  # common_tags = {
  #   Project     = "sentinel"
  #   Environment = var.environment
  # }
}

#------------------------------------------------------------------------------
# Gateway VPC - Public-facing services
#------------------------------------------------------------------------------
module "vpc_gateway" {
  source = "../../modules/vpc"

  vpc_name           = "vpc-gateway"
  vpc_cidr           = var.gateway_vpc_cidr
  availability_zones = local.azs
  cluster_name       = "eks-gateway"
  enable_nat_gateway = true
  enable_flow_logs   = var.enable_flow_logs

  tags = {}
}

#------------------------------------------------------------------------------
# Backend VPC - Internal services
#------------------------------------------------------------------------------
module "vpc_backend" {
  source = "../../modules/vpc"

  vpc_name           = "vpc-backend"
  vpc_cidr           = var.backend_vpc_cidr
  availability_zones = local.azs
  cluster_name       = "eks-backend"
  enable_nat_gateway = true
  enable_flow_logs   = var.enable_flow_logs

  tags = {}
}

#------------------------------------------------------------------------------
# VPC Peering - Private connectivity between VPCs
#------------------------------------------------------------------------------
module "vpc_peering" {
  source = "../../modules/vpc-peering"

  peering_name = "gateway-to-backend"

  requester_vpc_id         = module.vpc_gateway.vpc_id
  requester_vpc_cidr       = module.vpc_gateway.vpc_cidr
  requester_route_table_id = module.vpc_gateway.private_route_table_id

  accepter_vpc_id         = module.vpc_backend.vpc_id
  accepter_vpc_cidr       = module.vpc_backend.vpc_cidr
  accepter_route_table_id = module.vpc_backend.private_route_table_id

  tags = {}

  depends_on = [
    module.vpc_gateway,
    module.vpc_backend
  ]
}

#------------------------------------------------------------------------------
# EKS Gateway Cluster
#------------------------------------------------------------------------------
module "eks_gateway" {
  source = "../../modules/eks"

  cluster_name       = "eks-gateway"
  vpc_id             = module.vpc_gateway.vpc_id
  subnet_ids         = module.vpc_gateway.private_subnet_ids
  kubernetes_version = var.kubernetes_version

  enable_public_endpoint = true
  public_access_cidrs    = var.eks_public_access_cidrs

  node_instance_types = var.node_instance_types
  capacity_type       = var.capacity_type
  node_desired_size   = var.gateway_node_count
  node_min_size       = 1
  node_max_size       = 2

  node_labels = {
    "layer" = "gateway"
    "role"  = "proxy"
  }

  enable_irsa = true

  enabled_cluster_log_types = var.enable_cluster_logs ? ["api", "audit", "authenticator"] : []

  tags = {}

  # Ensure VPC and peering are fully set up before creating EKS
  depends_on = [
    module.vpc_gateway,
    module.vpc_peering
  ]
}

#------------------------------------------------------------------------------
# EKS Backend Cluster
#------------------------------------------------------------------------------
module "eks_backend" {
  source = "../../modules/eks"

  cluster_name       = "eks-backend"
  vpc_id             = module.vpc_backend.vpc_id
  subnet_ids         = module.vpc_backend.private_subnet_ids
  kubernetes_version = var.kubernetes_version

  enable_public_endpoint = true
  public_access_cidrs    = var.eks_public_access_cidrs

  node_instance_types = var.node_instance_types
  capacity_type       = var.capacity_type
  node_desired_size   = var.backend_node_count
  node_min_size       = 1
  node_max_size       = 2

  node_labels = {
    "layer" = "backend"
    "role"  = "application"
  }

  enable_irsa = true

  enabled_cluster_log_types = var.enable_cluster_logs ? ["api", "audit", "authenticator"] : []

  tags = {}

  # Ensure VPC and peering are fully set up before creating EKS
  depends_on = [
    module.vpc_backend,
    module.vpc_peering
  ]
}

#------------------------------------------------------------------------------
# Cross-VPC Security Groups
#------------------------------------------------------------------------------
module "security_groups" {
  source = "../../modules/security-groups"

  gateway_vpc_id                 = module.vpc_gateway.vpc_id
  gateway_vpc_cidr               = module.vpc_gateway.vpc_cidr
  gateway_private_subnet_cidrs   = module.vpc_gateway.private_subnet_cidrs
  gateway_cluster_name           = module.eks_gateway.cluster_name
  gateway_node_security_group_id = module.eks_gateway.node_security_group_id

  backend_node_security_group_id = module.eks_backend.node_security_group_id
  backend_vpc_cidr               = module.vpc_backend.vpc_cidr
  backend_port                   = 8080
  gateway_proxy_port             = 80

  allowed_ingress_cidrs = var.alb_ingress_cidrs

  tags = {}

  depends_on = [
    module.eks_gateway,
    module.eks_backend
  ]
}

#------------------------------------------------------------------------------
# GitHub Actions IAM Role - COMMENTED OUT (No IAM tag role access)
# NOTE: iam:CreateOpenIDConnectProvider is NOT in the allowed actions
# The OIDC provider must be created by an admin, or use static credentials
#------------------------------------------------------------------------------

# GitHub OIDC Provider - CANNOT be created with current permissions
# resource "aws_iam_openid_connect_provider" "github_actions" {
#   count = var.enable_github_oidc ? 1 : 0
#   url             = "https://token.actions.githubusercontent.com"
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
# }

# Data source to reference existing GitHub OIDC provider (if created by admin)
# data "aws_iam_openid_connect_provider" "github_actions" {
#   count = var.enable_github_oidc ? 1 : 0
#   url   = "https://token.actions.githubusercontent.com"
# }

# IAM Role for GitHub Actions - COMMENTED OUT (no IAM tag role access)
# resource "aws_iam_role" "github_actions" {
#   count = var.enable_github_oidc ? 1 : 0
#   name = "sentinel-github-actions-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = try(data.aws_iam_openid_connect_provider.github_actions[0].arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com")
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
#           }
#           StringLike = {
#             "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
#           }
#         }
#       }
#     ]
#   })
# }

# Custom policy for GitHub Actions role - COMMENTED OUT
# resource "aws_iam_role_policy" "github_actions_custom" {
#   count = var.enable_github_oidc ? 1 : 0
#   name = "github-actions-sentinel-policy"
#   role = aws_iam_role.github_actions[0].id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "eks:DescribeCluster",
#           "eks:ListClusters",
#           "eks:AccessKubernetesApi"
#         ]
#         Resource = [
#           module.eks_gateway.cluster_arn,
#           module.eks_backend.cluster_arn
#         ]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "ecr:GetAuthorizationToken",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }
