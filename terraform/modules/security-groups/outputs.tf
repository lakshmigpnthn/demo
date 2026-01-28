# Security Groups Module Outputs

output "gateway_alb_security_group_id" {
  description = "Security group ID for the Gateway ALB"
  value       = aws_security_group.gateway_alb.id
}

output "gateway_alb_security_group_arn" {
  description = "ARN of the Gateway ALB security group"
  value       = aws_security_group.gateway_alb.arn
}
