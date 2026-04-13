# Terraform Outputs for Hojadevida-izador Infrastructure
# These outputs describe the infrastructure layer (VPC, ECS, ALB, monitoring)
# Backend resources (Lambda, API Gateway, Cognito, DynamoDB, S3) are managed by SAM

# ============================================================================
# Backend Resources (SAM-Managed)
# ============================================================================
# API Gateway Endpoint: Retrieve from SAM stack outputs after deployment
#   aws cloudformation describe-stacks --stack-name hojadevida-backend-{env} --query 'Stacks[0].Outputs' --region us-east-1
#
# Cognito User Pool: Retrieve from SAM stack outputs
# DynamoDB Table: Retrieve from SAM stack outputs
# S3 Bucket: Retrieve from SAM stack outputs
# Lambda Functions: Retrieve from SAM stack outputs

# ============================================================================
# ECS Outputs (Frontend Infrastructure)
# ============================================================================
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.frontend.name
}

# ============================================================================
# ALB Outputs (Frontend Load Balancer)
# ============================================================================
output "alb_dns_name" {
  description = "DNS name of the load balancer (frontend URL)"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.ecs.arn
}

# ============================================================================
# VPC Outputs (Network Infrastructure)
# ============================================================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_eips" {
  description = "Elastic IPs of NAT Gateways (if enabled)"
  value       = var.enable_nat_gateway ? aws_eip.nat_1[*].public_ip : []
}

# ============================================================================
# Security Group Outputs
# ============================================================================
output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs.id
}

# ============================================================================
# IAM Outputs (Infrastructure Roles)
# ============================================================================
output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "github_oidc_role_arn" {
  description = "ARN of GitHub OIDC role for CI/CD"
  value       = aws_iam_role.github_oidc_role.arn
}

# ============================================================================
# CloudWatch Outputs (Infrastructure Monitoring)
# ============================================================================
output "cloudwatch_log_group_ecs" {
  description = "CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "cloudwatch_log_group_infrastructure" {
  description = "CloudWatch log group for infrastructure monitoring"
  value       = aws_cloudwatch_log_group.infrastructure_logs.name
}

# ============================================================================
# Account and Region Info
# ============================================================================
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# ============================================================================
# Deployment Summary
# ============================================================================
output "deployment_summary" {
  description = "Deployment summary for easy reference"
  value       = <<-EOT
    ========================================
    Hojadevida-izador Infrastructure Summary
    ========================================
    Environment:        ${var.environment}
    AWS Account:        ${data.aws_caller_identity.current.account_id}
    AWS Region:         ${data.aws_region.current.name}
    
    Frontend URL:       http://${aws_lb.main.dns_name}
    
    ECS Cluster:        ${aws_ecs_cluster.main.name}
    Load Balancer:      ${aws_lb.main.dns_name}
    
    VPC ID:             ${aws_vpc.main.id}
    VPC CIDR:           ${aws_vpc.main.cidr_block}
    
    CloudWatch Logs:    ${aws_cloudwatch_log_group.ecs.name}
    
    ========================================
    Backend Resources (SAM-Managed):
    ========================================
    Retrieve from SAM stack outputs:
      aws cloudformation describe-stacks \\
        --stack-name hojadevida-backend-${var.environment} \\
        --query 'Stacks[0].Outputs' \\
        --region ${data.aws_region.current.name}
    
    This will show:
    - API Gateway Endpoint (Backend API)
    - Cognito User Pool & Client
    - DynamoDB Table (CVs)
    - S3 Bucket (CVs Storage)
    - Lambda Functions
    ========================================
  EOT
}
