# Bootstrap Configuration - S3 Backend Resources
# Run this ONCE to create the S3 bucket for Terraform state
# 
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#
# NOTE: This bootstrap uses local state intentionally.
# After creation, the main infrastructure will use the S3 backend.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Default tags commented out - no access
  # default_tags {
  #   tags = {
  #     Project     = "sentinel"
  #     Environment = "shared"
  #     ManagedBy   = "terraform-bootstrap"
  #   }
  # }
}

variable "aws_region" {
  description = "AWS region for state resources"
  type        = string
  default     = "us-west-2"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "sentinel-terraform-rapyd-lg"
}

# DynamoDB table name - commented out due to no access
# variable "dynamodb_table_name" {
#   description = "Name of the DynamoDB table for state locking"
#   type        = string
#   default     = "sentinel-terraform-locks"
# }

#------------------------------------------------------------------------------
# S3 Bucket for Terraform State
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of this bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning for state file history and recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy to enforce SSL/TLS
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

#------------------------------------------------------------------------------
# DynamoDB Table for State Locking - COMMENTED OUT (No Access)
#------------------------------------------------------------------------------
# resource "aws_dynamodb_table" "terraform_locks" {
#   name         = var.dynamodb_table_name
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
#
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#
#   point_in_time_recovery {
#     enabled = true
#   }
# }

#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

# DynamoDB output commented out
# output "dynamodb_table_name" {
#   description = "Name of the DynamoDB table for state locking"
#   value       = aws_dynamodb_table.terraform_locks.name
# }

output "backend_config" {
  description = "Backend configuration to add to providers.tf"
  value       = <<-EOT
    
    # Add this to terraform/environments/dev/providers.tf
    terraform {
      backend "s3" {
        bucket  = "${aws_s3_bucket.terraform_state.id}"
        key     = "dev/terraform.tfstate"
        region  = "${var.aws_region}"
        encrypt = true
        # DynamoDB locking disabled - no access
      }
    }
  EOT
}

