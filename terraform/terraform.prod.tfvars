# Terraform Variables for Production Environment
# Production-specific overrides for hojadevida-izador

aws_region   = "us-east-1"
environment  = "prod"
project_name = "hojadevida-izador"
app_name     = "hojadevida"

# Cognito
cognito_user_pool_name           = "hojadevida-izador-users"
cognito_auto_verified_attributes = ["email"]

# Lambda (Higher timeout for production)
lambda_runtime = "nodejs20.x"
lambda_timeout = 300 # Longer timeout for Bedrock processing

# Bedrock Configuration (same for prod)
bedrock_model_id    = "anthropic.claude-3-haiku-20240307-v1:0"
bedrock_max_tokens  = 1800
bedrock_temperature = 0.3

# DynamoDB
dynamodb_billing_mode = "PAY_PER_REQUEST"

# API Gateway CORS (Production domains)
cors_allowed_origins = ["https://hojadevida.example.com", "https://www.hojadevida.example.com"]
cors_allowed_methods = ["GET", "POST", "OPTIONS"]
cors_allowed_headers = ["Content-Type", "Authorization"]
cors_max_age         = 3600 # Longer cache for production

# ECS (More instances for production)
ecs_container_cpu    = 512  # Higher than dev
ecs_container_memory = 1024 # Higher than dev
ecs_desired_count    = 3    # More instances than dev
ecs_task_port        = 3000

# ALB
alb_enable_deletion_protection = true # Protect from accidental deletion
enable_nat_gateway             = true # Enable NAT for production security

# S3 Lifecycle (Longer retention for production)
s3_lifecycle_retention_days = 365 # 1 year for production
s3_glacier_transition_days  = 90  # Archive after 90 days

# GitHub OIDC
github_org  = "estanixx"
github_repo = "hojadevida-izador"

# CloudWatch (Stricter monitoring for production)
cloudwatch_log_retention_days   = 30 # Longer retention
lambda_error_threshold          = 3  # Lower threshold for alerts
lambda_error_evaluation_periods = 2  # More periods

# SSM Parameter Store
ssm_parameter_tier = "Standard"

# Cost estimation (Higher for production)
bedrock_token_estimate = 5000
