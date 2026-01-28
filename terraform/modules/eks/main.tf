# EKS Module - Creates an EKS cluster with managed node groups
# Follows AWS and security best practices

# Tags removed - no IAM tag role access

#------------------------------------------------------------------------------
# EKS Cluster IAM Role
# Using eks- prefix as required by the challenge constraints
#------------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "eks-${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  # Tags removed - no IAM tag role access
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

#------------------------------------------------------------------------------
# EKS Cluster Security Group
#------------------------------------------------------------------------------
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg-"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  # Tags removed - no IAM tag role access

  lifecycle {
    create_before_destroy = true
  }
}

# Allow all outbound traffic from cluster
resource "aws_security_group_rule" "cluster_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
  description       = "Allow all outbound traffic"
}

#------------------------------------------------------------------------------
# EKS Cluster
#------------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_endpoint
    public_access_cidrs     = var.enable_public_endpoint ? var.public_access_cidrs : null
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Enable control plane logging (all types for production)
  enabled_cluster_log_types = var.enabled_cluster_log_types

  # NOTE: Secrets encryption with KMS is disabled due to IAM permission constraints
  # The challenge explicitly denies kms:* actions. In production, uncomment this:
  # encryption_config {
  #   provider {
  #     key_arn = var.kms_key_arn
  #   }
  #   resources = ["secrets"]
  # }

  # Tags removed - no IAM tag role access

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

#------------------------------------------------------------------------------
# EKS Node Group IAM Role
# Using eks- prefix as required by the challenge constraints
#------------------------------------------------------------------------------
resource "aws_iam_role" "node" {
  name = "eks-${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  # Tags removed - no IAM tag role access
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

#------------------------------------------------------------------------------
# EKS Node Group Security Group
#------------------------------------------------------------------------------
resource "aws_security_group" "node" {
  name_prefix = "${var.cluster_name}-node-sg-"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  # Keep only the essential kubernetes.io tag for EKS discovery
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "node_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.node.id
  description              = "Allow node to node communication"
}

# Allow nodes to receive traffic from cluster control plane
resource "aws_security_group_rule" "node_from_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
  description              = "Allow worker Kubelets and pods to receive communication from cluster control plane"
}

# Allow control plane to communicate with nodes on port 443
resource "aws_security_group_rule" "node_https_from_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
  description              = "Allow pods running extension API servers to receive communication from cluster control plane"
}

# SECURITY: Restrictive egress rules for nodes
# Allow HTTPS outbound (for AWS APIs, ECR, etc.)
resource "aws_security_group_rule" "node_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
  description       = "Allow HTTPS outbound for AWS APIs and container registries"
}

# Allow DNS outbound
resource "aws_security_group_rule" "node_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
  description       = "Allow DNS TCP outbound"
}

resource "aws_security_group_rule" "node_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
  description       = "Allow DNS UDP outbound"
}

# Allow NTP outbound (time sync)
resource "aws_security_group_rule" "node_egress_ntp" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
  description       = "Allow NTP outbound for time synchronization"
}

# Allow node-to-node communication within VPC
resource "aws_security_group_rule" "node_egress_internal" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.node.id
  description       = "Allow all traffic between nodes"
}

# Allow traffic to EKS control plane
resource "aws_security_group_rule" "node_egress_to_cluster" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
  description              = "Allow nodes to communicate with EKS control plane"
}

# Allow cluster to communicate with nodes
resource "aws_security_group_rule" "cluster_to_node" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow cluster control plane to communicate with worker nodes"
}

resource "aws_security_group_rule" "cluster_to_node_https" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow cluster control plane to communicate with worker nodes on 443"
}

#------------------------------------------------------------------------------
# EKS Managed Node Group
#------------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = var.capacity_type

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Use latest EKS-optimized AMI
  ami_type = "AL2_x86_64"

  labels = merge(
    var.node_labels,
    {
      "cluster" = var.cluster_name
    }
  )

  # Tags removed - no IAM tag role access

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

#------------------------------------------------------------------------------
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# NOTE: iam:CreateOpenIDConnectProvider is NOT in allowed actions
# This is disabled by default due to IAM permission constraints
# In production, request this permission or have an admin create it
#------------------------------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# OIDC Provider - Commented out due to IAM permission constraints
# Uncomment if iam:CreateOpenIDConnectProvider permission is granted
# resource "aws_iam_openid_connect_provider" "cluster" {
#   count = var.enable_irsa ? 1 : 0
#
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
#   url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
# }

#------------------------------------------------------------------------------
# aws-auth ConfigMap for additional IAM mappings
# Note: This is managed separately via Kubernetes provider
#------------------------------------------------------------------------------
