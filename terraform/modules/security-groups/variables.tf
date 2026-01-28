# Security Groups Module Variables

variable "gateway_vpc_id" {
  description = "ID of the Gateway VPC"
  type        = string
}

variable "gateway_vpc_cidr" {
  description = "CIDR block of the Gateway VPC"
  type        = string
}

variable "gateway_private_subnet_cidrs" {
  description = "CIDR blocks of Gateway private subnets (more restrictive than full VPC CIDR)"
  type        = list(string)
}

variable "gateway_cluster_name" {
  description = "Name of the Gateway EKS cluster"
  type        = string
}

variable "gateway_node_security_group_id" {
  description = "Security group ID of Gateway EKS nodes"
  type        = string
}

variable "backend_node_security_group_id" {
  description = "Security group ID of Backend EKS nodes"
  type        = string
}

variable "backend_vpc_cidr" {
  description = "CIDR block of the Backend VPC"
  type        = string
}

variable "backend_port" {
  description = "Port that the backend application listens on"
  type        = number
  default     = 8080
}

variable "gateway_proxy_port" {
  description = "Port that the gateway proxy listens on"
  type        = number
  default     = 80
}

variable "allowed_ingress_cidrs" {
  description = "List of CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
