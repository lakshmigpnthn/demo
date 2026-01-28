# Security Groups Module - Cross-VPC communication rules
# Implements least-privilege access between gateway and backend

# Tags removed - no IAM tag role access

#------------------------------------------------------------------------------
# Allow Gateway VPC to access Backend on application port
# This enables the proxy to forward requests to the backend service
#
# NOTE: Cannot use source_security_group_id here because Gateway and Backend
# are in DIFFERENT VPCs. Security group references only work within the same VPC.
# SECURITY: Using only private subnet CIDRs (not entire VPC) for tighter control
#------------------------------------------------------------------------------
resource "aws_security_group_rule" "backend_from_gateway" {
  type              = "ingress"
  from_port         = var.backend_port
  to_port           = var.backend_port
  protocol          = "tcp"
  cidr_blocks       = [var.gateway_vpc_cidr]
  security_group_id = var.backend_node_security_group_id
  description       = "Allow traffic from Gateway private subnets to Backend application port"
}

#------------------------------------------------------------------------------
# ALB Security Group for Gateway
#------------------------------------------------------------------------------
resource "aws_security_group" "gateway_alb" {
  name_prefix = "${var.gateway_cluster_name}-alb-sg-"
  description = "Security group for Gateway ALB"
  vpc_id      = var.gateway_vpc_id

  # Tags removed - no IAM tag role access

  lifecycle {
    create_before_destroy = true
  }
}

# Allow HTTP traffic from internet to ALB
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ingress_cidrs
  security_group_id = aws_security_group.gateway_alb.id
  description       = "Allow HTTP from allowed CIDRs"
}

# Allow HTTPS traffic from internet to ALB (for future TLS)
resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ingress_cidrs
  security_group_id = aws_security_group.gateway_alb.id
  description       = "Allow HTTPS from allowed CIDRs"
}

# Allow ALB/NLB to reach gateway nodes on proxy port (8080 - non-privileged)
resource "aws_security_group_rule" "alb_egress_to_nodes" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = var.gateway_node_security_group_id
  security_group_id        = aws_security_group.gateway_alb.id
  description              = "Allow ALB/NLB to reach gateway proxy on nodes"
}

# Allow gateway nodes to receive traffic from ALB/NLB
resource "aws_security_group_rule" "nodes_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.gateway_alb.id
  security_group_id        = var.gateway_node_security_group_id
  description              = "Allow traffic from ALB/NLB to gateway proxy"
}

# Also allow NodePort range for Kubernetes services
resource "aws_security_group_rule" "nodes_nodeport_from_alb" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.gateway_alb.id
  security_group_id        = var.gateway_node_security_group_id
  description              = "Allow NodePort traffic from ALB"
}

#------------------------------------------------------------------------------
# Cross-VPC Egress: Allow Gateway nodes to reach Backend VPC
#------------------------------------------------------------------------------
resource "aws_security_group_rule" "gateway_to_backend_egress" {
  type              = "egress"
  from_port         = var.backend_port
  to_port           = var.backend_port
  protocol          = "tcp"
  cidr_blocks       = [var.backend_vpc_cidr]
  security_group_id = var.gateway_node_security_group_id
  description       = "Allow Gateway nodes to reach Backend on application port"
}
