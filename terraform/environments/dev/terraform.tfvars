# Development Environment Configuration
# Adjust these values as needed for your deployment

aws_region  = "us-west-2"
environment = "dev"

# VPC Configuration
gateway_vpc_cidr = "10.1.0.0/16"
backend_vpc_cidr = "10.2.0.0/16"

# VPC Flow Logs - disabled by default for PoC
# When enabled, creates IAM role with eks- prefix (eks-vpc-gateway-flow-logs-role)
enable_flow_logs = false

# EKS Configuration
kubernetes_version = "1.29"

# SECURITY: Restrict EKS API access to your IP only
eks_public_access_cidrs = ["94.202.9.226/32"]

# Node configuration (cost-optimized for PoC)
node_instance_types = ["t3.medium"]
capacity_type       = "ON_DEMAND"  # Use Spot for cost savings (~60% cheaper)if capacity is avl else on demand 
gateway_node_count  = 1       # Reduced to 1 node for PoC
backend_node_count  = 1       # Reduced to 1 node for PoC

# SECURITY: Enable EKS control plane logging for audit trail
enable_cluster_logs = true

# Security
# SECURITY: Restrict ALB access to your IP only
alb_ingress_cidrs = ["94.202.9.226/32"]

# GitHub OIDC for CI/CD
# IMPORTANT: Set to true ONLY if an admin has created the GitHub OIDC provider
# The current IAM policy does NOT allow iam:CreateOpenIDConnectProvider
# Alternative: Use AWS access keys stored as GitHub secrets
enable_github_oidc = false
github_org         = "your-org"
github_repo        = "sentinel-infrastructure"

#------------------------------------------------------------------------------
# IAM Permission Constraints Documentation
#------------------------------------------------------------------------------
# The following IAM permissions are available:
# - Full access: ec2, eks, elasticloadbalancing, ecr, s3, cloudwatch, logs, 
#                route53, autoscaling
# - IAM: Only Get/List/Simulate + CreateServiceLinkedRole
# - IAM Role Management: CreateRole, PutRolePolicy, AttachRolePolicy, PassRole,
#                        DetachRolePolicy, DeleteRole
#   BUT ONLY for roles matching: arn:aws:iam::*:role/eks-* or sentinel-*
#
# NOT Allowed:
# - iam:CreateOpenIDConnectProvider (OIDC providers must be pre-created)
# - iam:CreateInstanceProfile (use EKS managed node groups instead)
# - kms, secretsmanager, rds, lambda (explicitly denied)
#------------------------------------------------------------------------------

