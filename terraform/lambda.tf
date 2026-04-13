# ============================================================================
# Lambda Functions for Hojadevida-izador Application
# ============================================================================
#
# This file defines all Lambda functions needed for:
# - listCvs: Query and return all CVs for authenticated user
# - generateCv: Invoke Bedrock AI to generate new CV from user data
#
# All functions:
# - Use nodejs20.x runtime with 60-300s timeout depending on operation
# - Access DynamoDB CVs table and S3 bucket via IAM role
# - Integrate with Bedrock for AI-powered CV generation
# - Log to CloudWatch for monitoring and debugging
# - Reference handler.js from backend directory
#
# Design rationale:
# - Separate functions: single responsibility principle
# - generateCv has 5min timeout: Bedrock can be slow on first invocation
# - 512MB memory for generateCv: Bedrock processing requires memory
# - Environment variables inject resource names: avoids hardcoding
# - CloudWatch logs: required for debugging and monitoring
# ============================================================================

# ============================================================================
# Lambda Execution Role (reference from iam.tf)
# ============================================================================
# The Lambda execution role (aws_iam_role.lambda_execution_role) is defined
# in iam.tf and grants permissions to:
# - DynamoDB: read/write CV metadata
# - S3: upload generated CVs
# - Bedrock: invoke models for generation
# - CloudWatch: write logs
# - SSM Parameter Store: read configuration

# ============================================================================
# Lambda Function 1: listCvs
# ============================================================================
# Lists all CVs for the authenticated user.
# Handler: handler.listCvs
# Timeout: 60 seconds (sufficient for DynamoDB query)
# Memory: 128 MB (default, query-only operation)
#
# Environment variables:
# - CVS_TABLE: Name of DynamoDB table (from aws_dynamodb_table.cvs.name)
# - CVS_BUCKET: Name of S3 bucket (from aws_s3_bucket.cvs.id)
#
# CloudWatch: Automatically logs to /aws/lambda/hojadevida-listCvs-{env}

resource "aws_lambda_function" "list_cvs" {
  filename      = data.archive_file.lambda_handler.output_path
  function_name = "${var.app_name}-listCvs-${var.environment}"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "handler.listCvs"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = 128

  source_code_hash = data.archive_file.lambda_handler.output_base64sha256

  # ========================================================================
  # Environment Variables
  # ========================================================================
  # Injected at runtime: handler.js reads these to query DynamoDB/S3

  environment {
    variables = {
      CVS_TABLE   = aws_dynamodb_table.cvs.name
      CVS_BUCKET  = aws_s3_bucket.cvs.id
      ENVIRONMENT = var.environment
    }
  }

  # ========================================================================
  # Ephemeral Storage
  # ========================================================================
  # Default: 512 MB (sufficient for query results and temporary processing)

  ephemeral_storage {
    size = 512
  }

  # ========================================================================
  # Description and Tags
  # ========================================================================

  description = "List all CVs for authenticated user"

  tags = {
    Name        = "${var.app_name}-listCvs"
    Description = "Lists user's generated CVs"
    Component   = "Lambda"
    Function    = "listCvs"
  }

  depends_on = [
    aws_iam_role_policy.lambda_execution_policy,
    aws_cloudwatch_log_group.lambda_listcvs,
  ]
}

# ========================================================================
# CloudWatch Log Group: listCvs
# ========================================================================
# Enables viewing function logs in CloudWatch
# Log group created explicitly to set retention policy

resource "aws_cloudwatch_log_group" "lambda_listcvs" {
  name              = "/aws/lambda/${var.app_name}-listCvs-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name      = "${var.app_name}-listCvs-logs"
    Component = "Logging"
  }
}

# ============================================================================
# Lambda Function 2: generateCv
# ============================================================================
# Generates a new CV using Bedrock AI based on user input.
# Handler: handler.generateCv
# Timeout: 300 seconds (5 minutes - Bedrock can be slow)
# Memory: 512 MB (Bedrock processing requires more memory)
#
# Environment variables:
# - CVS_TABLE: DynamoDB table for storing CV metadata
# - CVS_BUCKET: S3 bucket for storing generated CV document
# - BEDROCK_MODEL_ID: Model to use (from var.bedrock_model_id)
# - BEDROCK_MAX_TOKENS: Max response tokens (from var.bedrock_max_tokens)
# - BEDROCK_TEMPERATURE: Model creativity (from var.bedrock_temperature)
#
# CloudWatch: Automatically logs to /aws/lambda/hojadevida-generateCv-{env}

resource "aws_lambda_function" "generate_cv" {
  filename      = data.archive_file.lambda_handler.output_path
  function_name = "${var.app_name}-generateCv-${var.environment}"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "handler.generateCv"
  runtime       = var.lambda_runtime
  timeout       = 300 # 5 minutes: Bedrock can be slow
  memory_size   = 512 # Bedrock processing needs more memory

  source_code_hash = data.archive_file.lambda_handler.output_base64sha256

  # ========================================================================
  # Environment Variables
  # ========================================================================
  # Injected at runtime: handler.js reads these for Bedrock configuration

  environment {
    variables = {
      CVS_TABLE           = aws_dynamodb_table.cvs.name
      CVS_BUCKET          = aws_s3_bucket.cvs.id
      BEDROCK_MODEL_ID    = var.bedrock_model_id
      BEDROCK_MAX_TOKENS  = var.bedrock_max_tokens
      BEDROCK_TEMPERATURE = var.bedrock_temperature
      ENVIRONMENT         = var.environment
    }
  }

  # ========================================================================
  # Ephemeral Storage
  # ========================================================================
  # 512 MB: sufficient for Bedrock response + temporary CV document

  ephemeral_storage {
    size = 512
  }

  # ========================================================================
  # Description and Tags
  # ========================================================================

  description = "Generate CV using Bedrock AI"

  tags = {
    Name        = "${var.app_name}-generateCv"
    Description = "Generates CVs using Bedrock"
    Component   = "Lambda"
    Function    = "generateCv"
  }

  depends_on = [
    aws_iam_role_policy.lambda_execution_policy,
    aws_cloudwatch_log_group.lambda_generatecv,
  ]
}

# ========================================================================
# CloudWatch Log Group: generateCv
# ========================================================================
# Enables viewing function logs in CloudWatch
# Log group created explicitly to set retention policy

resource "aws_cloudwatch_log_group" "lambda_generatecv" {
  name              = "/aws/lambda/${var.app_name}-generateCv-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name      = "${var.app_name}-generateCv-logs"
    Component = "Logging"
  }
}

# ============================================================================
# Data Source: Archive Lambda Handler
# ============================================================================
# Creates a ZIP file from backend/handler.js and dependencies
# Used by both Lambda functions to reference the same handler code
#
# Design note:
# - ZIP source: points to backend directory (contains handler.js + node_modules)
# - output_path: creates .zip in terraform working directory
# - source_code_hash: triggers Lambda update if source changes

data "archive_file" "lambda_handler" {
  type        = "zip"
  source_dir  = "${path.root}/../backend"
  output_path = "${path.root}/.terraform/lambda_handler.zip"

  # Exclude items that shouldn't be in the Lambda package
  excludes = [
    "README.md",
    ".gitignore",
    "serverless.yaml",
    ".serverless"
  ]
}

