# Variables for Hojadevida-izador Terraform configuration

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for tagging and naming resources"
  type        = string
  default     = "hojadevida-izador"
}

variable "app_name" {
  description = "Application name for resource naming"
  type        = string
  default     = "hojadevida"
}

# Cognito Configuration
variable "cognito_user_pool_name" {
  description = "Name of Cognito User Pool"
  type        = string
  default     = null
}

variable "cognito_auto_verified_attributes" {
  description = "Attributes that are auto-verified in Cognito"
  type        = list(string)
  default     = ["email"]
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for CV generation"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "bedrock_max_tokens" {
  description = "Maximum tokens for Bedrock response"
  type        = number
  default     = 1800
}

variable "bedrock_temperature" {
  description = "Temperature for Bedrock model (0.0 to 1.0)"
  type        = number
  default     = 0.3

  validation {
    condition     = var.bedrock_temperature >= 0.0 && var.bedrock_temperature <= 1.0
    error_message = "Temperature must be between 0.0 and 1.0."
  }
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

# API Gateway CORS Configuration
variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "cors_allowed_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "OPTIONS"]
}

variable "cors_allowed_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["Content-Type", "Authorization"]
}

variable "cors_max_age" {
  description = "Max age for CORS preflight cache in seconds"
  type        = number
  default     = 300
}

# ECS Configuration
variable "ecs_container_cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 256
}

variable "ecs_container_memory" {
  description = "Memory in MB for ECS task"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_task_port" {
  description = "Port the ECS task listens on"
  type        = number
  default     = 3000
}

variable "ecs_task_image_uri" {
  description = "ECR image URI for ECS task (optional, defaults to auto-generated)"
  type        = string
  default     = null
}

# VPC and Networking Configuration
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.16.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.16.32.0/20"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.16.48.0/20"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.16.0.0/20"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.16.16.0/20"
}

variable "application_name" {
  description = "Application name for resource naming (alias for app_name)"
  type        = string
  default     = "hojadevida"
}

# ALB Configuration
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection on ALB"
  type        = bool
  default     = false
}

variable "enable_https_alb" {
  description = "Enable HTTPS (443) on ALB in addition to HTTP (80)"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Whether to enable NAT Gateway for private subnets (production)"
  type        = bool
  default     = false
}

# S3 Configuration
variable "s3_lifecycle_retention_days" {
  description = "Days to retain noncurrent S3 versions"
  type        = number
  default     = 90
}

variable "s3_glacier_transition_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 365
}

# GitHub OIDC Configuration
variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "estanixx"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "hojadevida-izador"
}

# CloudWatch Configuration
variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "lambda_error_threshold" {
  description = "Error threshold for Lambda alarm"
  type        = number
  default     = 5
}

variable "lambda_error_evaluation_periods" {
  description = "Number of periods for Lambda error evaluation"
  type        = number
  default     = 1
}

# SSM Parameter Store Configuration
variable "ssm_parameter_tier" {
  description = "SSM Parameter Store tier (Standard or Advanced)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Advanced"], var.ssm_parameter_tier)
    error_message = "Tier must be either Standard or Advanced."
  }
}

variable "bedrock_token_estimate" {
  description = "Estimated tokens per CV for cost tracking"
  type        = number
  default     = 500
}

# ============================================================================
# Resource ARN Variables (from dynamodb.tf, s3.tf)
# ============================================================================
# These variables will be populated by outputs from other resource files.
# They define the specific AWS resources that IAM policies will reference.

variable "dynamodb_cvs_table_arn" {
  description = "ARN of the DynamoDB table storing CV metadata"
  type        = string
  default     = ""
}

variable "s3_cvs_bucket_arn" {
  description = "ARN of the S3 bucket for storing CV documents"
  type        = string
  default     = ""
}

variable "s3_terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state storage"
  type        = string
  default     = ""
}

variable "dynamodb_terraform_locks_table_arn" {
  description = "ARN of the DynamoDB table for Terraform state locks"
  type        = string
  default     = ""
}
