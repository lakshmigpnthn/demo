# Environment Variables

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------
variable "gateway_vpc_cidr" {
  description = "CIDR block for the Gateway VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "backend_vpc_cidr" {
  description = "CIDR block for the Backend VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false  # Disabled for PoC cost savings
}

#------------------------------------------------------------------------------
# EKS Configuration
#------------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.28"
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to access EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted in production
}

variable "node_instance_types" {
  description = "Instance types for EKS node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Capacity type for EKS nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "gateway_node_count" {
  description = "Desired number of nodes in gateway cluster"
  type        = number
  default     = 2
}

variable "backend_node_count" {
  description = "Desired number of nodes in backend cluster"
  type        = number
  default     = 2
}

variable "enable_cluster_logs" {
  description = "Enable EKS control plane logging"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Security Configuration
#------------------------------------------------------------------------------
variable "alb_ingress_cidrs" {
  description = "CIDRs allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

#------------------------------------------------------------------------------
# GitHub OIDC Configuration
# NOTE: Creating the OIDC provider requires iam:CreateOpenIDConnectProvider
# which is NOT in the allowed permissions. Set enable_github_oidc=true only
# if an admin has pre-created the GitHub OIDC provider in your account.
#------------------------------------------------------------------------------
variable "enable_github_oidc" {
  description = "Enable GitHub OIDC provider for CI/CD (requires pre-existing OIDC provider)"
  type        = bool
  default     = false  # Disabled by default due to IAM permission constraints
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "your-org"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "sentinel-infrastructure"
}
