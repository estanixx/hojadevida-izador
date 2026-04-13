# Terraform Outputs for Hojadevida-izador
# These are exported for use by frontend and documentation

# API Gateway Outputs
output "http_api_url" {
  description = "The invoke URL of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "http_api_id" {
  description = "The ID of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.http_api.id
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "The Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_name" {
  description = "The Cognito User Pool name"
  value       = aws_cognito_user_pool.main.name
}

output "cognito_user_pool_client_id" {
  description = "The Cognito User Pool Client ID (for frontend)"
  value       = aws_cognito_user_pool_client.web.client_id
}

output "cognito_user_pool_endpoint" {
  description = "The Cognito User Pool endpoint"
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}

# DynamoDB Outputs
output "dynamodb_cvs_table_name" {
  description = "Name of the DynamoDB table for CVs"
  value       = aws_dynamodb_table.cvs.name
}

output "dynamodb_cvs_table_arn" {
  description = "ARN of the DynamoDB table for CVs"
  value       = aws_dynamodb_table.cvs.arn
}

# S3 Outputs
output "s3_cvs_bucket_name" {
  description = "Name of the S3 bucket for CVs"
  value       = aws_s3_bucket.cvs.id
}

output "s3_cvs_bucket_arn" {
  description = "ARN of the S3 bucket for CVs"
  value       = aws_s3_bucket.cvs.arn
}

# Lambda Outputs
output "lambda_list_cvs_function_name" {
  description = "Name of the listCvs Lambda function"
  value       = aws_lambda_function.list_cvs.function_name
}

output "lambda_list_cvs_function_arn" {
  description = "ARN of the listCvs Lambda function"
  value       = aws_lambda_function.list_cvs.arn
}

output "lambda_generate_cv_function_name" {
  description = "Name of the generateCv Lambda function"
  value       = aws_lambda_function.generate_cv.function_name
}

output "lambda_generate_cv_function_arn" {
  description = "ARN of the generateCv Lambda function"
  value       = aws_lambda_function.generate_cv.arn
}

# ECS Outputs
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

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer"
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

# VPC Outputs
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

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs.id
}

# IAM Outputs
output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

# CloudWatch Outputs
output "cloudwatch_log_group_lambda" {
  description = "CloudWatch log group for Lambda functions"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_ecs" {
  description = "CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

# Frontend Environment Variables (for GitHub Actions)
output "frontend_env_vars" {
  description = "Environment variables for frontend (as JSON)"
  value = jsonencode({
    NEXT_PUBLIC_API_URL              = aws_apigatewayv2_api.http_api.api_endpoint
    NEXT_PUBLIC_COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
    NEXT_PUBLIC_COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.web.client_id
    NEXT_PUBLIC_COGNITO_REGION       = data.aws_region.current.name
  })
}

# SSM Parameters (for reference in future phases)
output "ssm_bedrock_config_path" {
  description = "SSM parameter path for Bedrock configuration"
  value       = "/hojadevida/${var.environment}/bedrock"
}

output "ssm_lambda_config_path" {
  description = "SSM parameter path for Lambda configuration"
  value       = "/hojadevida/${var.environment}/lambda"
}

# GitHub OIDC Outputs
output "github_oidc_role_arn" {
  description = "ARN of GitHub OIDC role for CI/CD"
  value       = aws_iam_role.github_oidc.arn
}

# Account and Region Info
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

output "deployment_summary" {
  description = "Deployment summary for easy reference"
  value       = <<-EOT
    ========================================
    Hojadevida-izador Deployment Summary
    ========================================
    Environment:        ${var.environment}
    AWS Account:        ${data.aws_caller_identity.current.account_id}
    AWS Region:         ${data.aws_region.current.name}
    
    API Endpoint:       ${aws_apigatewayv2_api.http_api.api_endpoint}
    Frontend URL:       http://${aws_lb.main.dns_name}
    
    Cognito User Pool:  ${aws_cognito_user_pool.main.id}
    Cognito Client:     ${aws_cognito_user_pool_client.web.client_id}
    
    Lambda Functions:   ${aws_lambda_function.list_cvs.function_name}, ${aws_lambda_function.generate_cv.function_name}
    DynamoDB Table:     ${aws_dynamodb_table.cvs.name}
    S3 Bucket:          ${aws_s3_bucket.cvs.id}
    
    ECS Cluster:        ${aws_ecs_cluster.main.name}
    Load Balancer:      ${aws_lb.main.dns_name}
    
    CloudWatch Logs:    ${aws_cloudwatch_log_group.lambda.name}, ${aws_cloudwatch_log_group.ecs.name}
    ========================================
  EOT
}
