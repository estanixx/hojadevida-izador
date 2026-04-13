# Default Terraform Variables for hojadevida-izador
# Override these in terraform.tfvars.dev, terraform.tfvars.staging, terraform.tfvars.prod

aws_region   = "us-east-1"
environment  = "dev"
project_name = "hojadevida-izador"
app_name     = "hojadevida"

# Cognito
cognito_user_pool_name           = "hojadevida-izador-users"
cognito_auto_verified_attributes = ["email"]

# Lambda
lambda_runtime = "nodejs20.x"
lambda_timeout = 60

# Bedrock Configuration
bedrock_model_id    = "anthropic.claude-3-haiku-20240307-v1:0"
bedrock_max_tokens  = 1800
bedrock_temperature = 0.3

# DynamoDB
dynamodb_billing_mode = "PAY_PER_REQUEST"

# API Gateway CORS
cors_allowed_origins = ["http://localhost:3000"]
cors_allowed_methods = ["GET", "POST", "OPTIONS"]
cors_allowed_headers = ["Content-Type", "Authorization"]
cors_max_age         = 300

# ECS
ecs_container_cpu    = 256
ecs_container_memory = 512
ecs_desired_count    = 2
ecs_task_port        = 3000

# ALB
alb_enable_deletion_protection = false
enable_nat_gateway             = false

# S3 Lifecycle
s3_lifecycle_retention_days = 90
s3_glacier_transition_days  = 365

# GitHub OIDC
github_org  = "estanixx"
github_repo = "hojadevida-izador"

# CloudWatch
cloudwatch_log_retention_days   = 7
lambda_error_threshold          = 5
lambda_error_evaluation_periods = 1

# SSM Parameter Store
ssm_parameter_tier = "Standard"

# Cost estimation
bedrock_token_estimate = 500
