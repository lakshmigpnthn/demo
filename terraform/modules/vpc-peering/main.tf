# VPC Peering Module - Establishes private connectivity between VPCs
# Enables secure cross-cluster communication

# Tags removed - no IAM tag role access

#------------------------------------------------------------------------------
# VPC Peering Connection
#------------------------------------------------------------------------------
resource "aws_vpc_peering_connection" "main" {
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_region   = var.peer_region
  auto_accept   = var.peer_region == null ? true : false

  # Tags removed - no IAM tag role access
}

# Auto-accept peering if same region
resource "aws_vpc_peering_connection_accepter" "main" {
  count = var.peer_region == null ? 0 : 1

  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true

  # Tags removed - no IAM tag role access
}

#------------------------------------------------------------------------------
# VPC Peering Connection Options
#------------------------------------------------------------------------------
resource "aws_vpc_peering_connection_options" "requester" {
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  depends_on = [aws_vpc_peering_connection.main]
}

resource "aws_vpc_peering_connection_options" "accepter" {
  count = var.peer_region == null ? 1 : 0

  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  depends_on = [aws_vpc_peering_connection.main]
}

#------------------------------------------------------------------------------
# Routes from Requester VPC to Accepter VPC
#------------------------------------------------------------------------------
resource "aws_route" "requester_to_accepter" {
  route_table_id            = var.requester_route_table_id
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [aws_vpc_peering_connection.main]
}

#------------------------------------------------------------------------------
# Routes from Accepter VPC to Requester VPC
#------------------------------------------------------------------------------
resource "aws_route" "accepter_to_requester" {
  route_table_id            = var.accepter_route_table_id
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [aws_vpc_peering_connection.main]
}
