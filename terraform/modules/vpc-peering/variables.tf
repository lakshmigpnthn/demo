# VPC Peering Module Variables

variable "peering_name" {
  description = "Name for the VPC peering connection"
  type        = string
}

variable "requester_vpc_id" {
  description = "ID of the requester VPC (gateway)"
  type        = string
}

variable "requester_vpc_cidr" {
  description = "CIDR block of the requester VPC"
  type        = string
}

variable "requester_route_table_id" {
  description = "Route table ID for the requester VPC private subnets"
  type        = string
}

variable "accepter_vpc_id" {
  description = "ID of the accepter VPC (backend)"
  type        = string
}

variable "accepter_vpc_cidr" {
  description = "CIDR block of the accepter VPC"
  type        = string
}

variable "accepter_route_table_id" {
  description = "Route table ID for the accepter VPC private subnets"
  type        = string
}

variable "peer_region" {
  description = "Region of the accepter VPC (null if same region)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
