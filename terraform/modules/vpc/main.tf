# VPC Module - Creates a VPC with private subnets for EKS
# This module follows AWS best practices for EKS networking

locals {
  # Tags required for EKS to discover subnets - these are essential
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

#------------------------------------------------------------------------------
# VPC
#------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags removed - no IAM tag role access
}

#------------------------------------------------------------------------------
# Restrict Default Security Group (CKV2_AWS_12)
# AWS best practice: Default SG should have no rules
#------------------------------------------------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules = fully restrictive
  # This prevents accidental use of the default security group

  # Tags removed - no IAM tag role access
}

#------------------------------------------------------------------------------
# Internet Gateway (required for NAT Gateway)
#------------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  # Tags removed - no IAM tag role access
}

#------------------------------------------------------------------------------
# Public Subnet (single - for NAT Gateway only, no public EC2s)
#------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 100)
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = false  # Security: No auto-assign public IPs

  # Tags removed - no IAM tag role access
}

#------------------------------------------------------------------------------
# Private Subnets (for EKS nodes and workloads)
#------------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  # EKS-required tags - these are essential for cluster discovery
  tags = local.private_subnet_tags
}

#------------------------------------------------------------------------------
# Elastic IP for NAT Gateway
#------------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  # Tags removed - no IAM tag role access

  depends_on = [aws_internet_gateway.main]
}

#------------------------------------------------------------------------------
# NAT Gateway (single for cost optimization in PoC)
#------------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  # Tags removed - no IAM tag role access

  depends_on = [aws_internet_gateway.main]
}

#------------------------------------------------------------------------------
# Route Tables
#------------------------------------------------------------------------------

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Tags removed - no IAM tag role access
}

# Public Route to Internet Gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Subnet Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Tags removed - no IAM tag role access
}

# Private Route to NAT Gateway (for outbound internet access)
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# Private Subnet Associations
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

#------------------------------------------------------------------------------
# VPC Flow Logs - COMMENTED OUT (requires IAM role creation)
# Note: Uses eks- prefix for IAM role to comply with permission constraints
#------------------------------------------------------------------------------
# resource "aws_flow_log" "main" {
#   count = var.enable_flow_logs ? 1 : 0
#
#   vpc_id                   = aws_vpc.main.id
#   traffic_type             = "ALL"
#   iam_role_arn             = aws_iam_role.flow_logs[0].arn
#   log_destination_type     = "cloud-watch-logs"
#   log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
#   max_aggregation_interval = 60
# }

# resource "aws_cloudwatch_log_group" "flow_logs" {
#   count = var.enable_flow_logs ? 1 : 0
#
#   name              = "/aws/vpc/${var.vpc_name}/flow-logs"
#   retention_in_days = 30
# }

# IAM Role for VPC Flow Logs - COMMENTED OUT
# resource "aws_iam_role" "flow_logs" {
#   count = var.enable_flow_logs ? 1 : 0
#   name = "eks-${var.vpc_name}-flow-logs-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "vpc-flow-logs.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy" "flow_logs" {
#   count = var.enable_flow_logs ? 1 : 0
#   name = "flow-logs-policy"
#   role = aws_iam_role.flow_logs[0].id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams"
#         ]
#         Effect   = "Allow"
#         Resource = "*"
#       }
#     ]
#   })
# }
