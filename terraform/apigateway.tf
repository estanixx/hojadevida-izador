# ============================================================================
# API Gateway Resources for Hojadevida-izador Application
# ============================================================================
#
# This file defines all API Gateway resources needed for:
# - HTTP API: RESTful endpoint for CV operations
# - JWT Authorizer: Validates Cognito tokens on all requests
# - Integrations: Connects API routes to Lambda functions
# - CORS: Restricts cross-origin requests to allowed frontend domains
#
# Architecture:
# - HTTP API (v2): Modern, cost-effective API Gateway
# - JWT authorizer: Validates tokens from Cognito User Pool
# - Two routes: GET /cvs (list) and POST /cvs/generate (create)
# - All routes require authentication
# - CORS allows specified frontend domains only
#
# Design rationale:
# - HTTP API < REST API: simpler, cheaper, sufficient for this use case
# - JWT authorizer: serverless validation, no extra Lambda calls
# - Cognito as issuer: centralized user management
# - CORS from vars: different origins per environment (dev/staging/prod)
# ============================================================================

# ============================================================================
# HTTP API
# ============================================================================
# Modern API Gateway providing RESTful endpoint for CV operations.
# Includes CORS configuration to restrict cross-origin requests.
#
# CORS settings:
# - allow_origins: var.cors_allowed_origins (e.g., ["http://localhost:3000"])
# - allow_methods: var.cors_allowed_methods (e.g., ["GET", "POST", "OPTIONS"])
# - allow_headers: var.cors_allowed_headers (e.g., ["Content-Type", "Authorization"])
# - max_age: var.cors_max_age (how long preflight is cached)
# - allow_credentials: false (not needed for public frontend)

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.app_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "Hojadevida API for CV generation and management"

  # ========================================================================
  # CORS Configuration
  # ========================================================================
  # Restricts cross-origin requests to specified frontend domains.
  # Prevents CORS attacks and ensures API is only consumed by trusted clients.

  cors_configuration {
    allow_origins     = var.cors_allowed_origins
    allow_methods     = var.cors_allowed_methods
    allow_headers     = var.cors_allowed_headers
    expose_headers    = ["Content-Length", "Content-Type"]
    max_age           = var.cors_max_age
    allow_credentials = false
  }

  # ========================================================================
  # Tags
  # ========================================================================

  tags = {
    Name        = "${var.app_name}-api"
    Description = "HTTP API for CV generation"
    Component   = "API"
  }
}

# ============================================================================
# JWT Authorizer
# ============================================================================
# Validates JWT tokens from Cognito on every request.
# Tokens are extracted from Authorization header and validated against
# Cognito User Pool.
#
# Token validation:
# - Issuer: Cognito User Pool endpoint
# - Audience: Cognito User Pool Client ID
# - Signature: Cognito validates token signature
# - Expiry: Lambda checks token exp claim
#
# Design note:
# - Authorizer is attached to routes (not at API level)
# - Failed authorization returns 401 Unauthorized
# - Successful authorization passes context to Lambda handlers

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.app_name}-cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web.client_id]
    issuer   = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }

  tags = {
    Name        = "${var.app_name}-cognito-authorizer"
    Description = "JWT authorizer for Cognito tokens"
    Component   = "Authorization"
  }
}

# ============================================================================
# Stage (Default)
# ============================================================================
# Routes all traffic through default stage with access logging enabled

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  # ========================================================================
  # Access Logging
  # ========================================================================
  # Logs all API requests to CloudWatch for monitoring and debugging

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      resourcePath       = "$context.resourcePath"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      integrationLatency = "$context.integration.latency"
      error              = "$context.error.message"
      authorizer         = "$context.authorizer.principalId"
    })
  }

  tags = {
    Name      = "${var.app_name}-default-stage"
    Component = "API"
  }

  depends_on = [aws_cloudwatch_log_group.api_gateway]
}

# ============================================================================
# Integration 1: listCvs
# ============================================================================
# Connects GET /cvs route to Lambda function.
# Payload format 2.0: newer HTTP payload format (recommended for HTTP API)

resource "aws_apigatewayv2_integration" "list_cvs" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.list_cvs.invoke_arn
  payload_format_version = "2.0"

  # ========================================================================
  # Timeout Configuration
  # ========================================================================
  # Default timeout is 29 seconds (API Gateway limit)
  # Lambda timeout is 60 seconds (for query processing)

  timeout_milliseconds = 29000
}

# ============================================================================
# Integration 2: generateCv
# ============================================================================
# Connects POST /cvs/generate route to Lambda function.
# Uses same payload format as listCvs integration.

resource "aws_apigatewayv2_integration" "generate_cv" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.generate_cv.invoke_arn
  payload_format_version = "2.0"

  # ========================================================================
  # Timeout Configuration
  # ========================================================================
  # Default timeout is 29 seconds (API Gateway limit)
  # Lambda timeout is 300 seconds (for Bedrock processing)
  # Note: API Gateway will timeout first; use client-side polling for long operations

  timeout_milliseconds = 29000
}

# ============================================================================
# Route 1: GET /cvs
# ============================================================================
# Retrieves all CVs for authenticated user.
# Requires JWT authorization (Cognito token).

resource "aws_apigatewayv2_route" "list_cvs" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "GET /cvs"
  target             = "integrations/${aws_apigatewayv2_integration.list_cvs.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id

  # ========================================================================
  # Request Parameters
  # ========================================================================
  # No path/query parameters for list operation
  # Authorization header is automatically extracted by authorizer
}

# ============================================================================
# Route 2: POST /cvs/generate
# ============================================================================
# Generates a new CV using Bedrock AI.
# Requires JWT authorization (Cognito token).
# Request body contains user data for CV generation.

resource "aws_apigatewayv2_route" "generate_cv" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "POST /cvs/generate"
  target             = "integrations/${aws_apigatewayv2_integration.generate_cv.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id

  # ========================================================================
  # Request Model (optional - can be added in Phase 2 for input validation)
  # ========================================================================
  # Phase 2: Add request schema validation to reject invalid payloads early
}

# ============================================================================
# Lambda Permissions
# ============================================================================
# Grants API Gateway permission to invoke both Lambda functions.
# Required for AWS_PROXY integration to work.

resource "aws_lambda_permission" "api_invoke_list_cvs" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_cvs.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_invoke_generate_cv" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_cv.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# ============================================================================
# CloudWatch Log Group: API Gateway Access Logs
# ============================================================================
# Captures all API requests for monitoring, debugging, and compliance.

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${var.app_name}-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name      = "${var.app_name}-api-logs"
    Component = "Logging"
  }
}

