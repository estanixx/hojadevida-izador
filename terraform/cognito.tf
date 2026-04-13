# Cognito User Pool and Client configuration
# Handles user authentication and authorization for the Hojadevida-izador application

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.app_name}-users-${var.environment}"

  username_attributes = ["email"]

  auto_verified_attributes = var.cognito_auto_verified_attributes

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Email verification message
  email_verification_message = "Your verification code is {####}"
  email_verification_subject = "Verify your email for Hojadevida-izador"

  # User attribute update settings
  user_attribute_update_settings {
    attributes_require_verification_before_update = var.cognito_auto_verified_attributes
  }

  # MFA settings
  mfa_configuration = "OFF"

  # User pool schema - define custom attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = false
    required                 = true
    developer_only_attribute = false
  }

  schema {
    name                     = "name"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false
  }

  schema {
    name                     = "given_name"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false
  }

  schema {
    name                     = "family_name"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false
  }

  schema {
    name                     = "phone_number"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false
  }

  # Deletion protection
  deletion_protection = "INACTIVE"

  tags = {
    Name = "${var.app_name}-user-pool"
  }
}

# Cognito User Pool Client for Web Application
resource "aws_cognito_user_pool_client" "web" {
  name = "${var.app_name}-web-client-${var.environment}"

  user_pool_id = aws_cognito_user_pool.main.id

  # Authentication flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user enumeration attacks
  prevent_user_existence_errors = "ENABLED"

  # Timeout settings (in seconds)
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30 * 24 * 60 # 30 days
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # CORS configuration
  allowed_oauth_flows = ["code", "implicit"]
  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile",
    "aws.cognito.signin.user.admin"
  ]

  allowed_oauth_flows_user_pool_client = true

  # Callback URLs - will be set via environment-specific tfvars
  callback_urls = [
    "http://localhost:3000/callback", # Dev
    "http://localhost:3000/auth/callback"
  ]

  logout_urls = [
    "http://localhost:3000/logout",
    "http://localhost:3000"
  ]

  supported_identity_providers = ["COGNITO"]

  # Generate client secret (important for security)
  generate_secret = false

  # Read attributes
  read_attributes = [
    "email",
    "email_verified",
    "name",
    "given_name",
    "family_name",
    "phone_number",
    "phone_number_verified",
    "updated_at"
  ]

  # Write attributes
  write_attributes = [
    "email",
    "name",
    "given_name",
    "family_name",
    "phone_number",
    "updated_at"
  ]
}

# Cognito User Pool Domain (for hosted UI, if needed)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.app_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# SSM Parameter Store: Store Cognito configuration for backend/frontend
resource "aws_ssm_parameter" "cognito_config" {
  name        = "/hojadevida/${var.environment}/cognito"
  description = "Cognito configuration for ${var.environment} environment"
  type        = "String"
  tier        = var.ssm_parameter_tier

  value = jsonencode({
    user_pool_id           = aws_cognito_user_pool.main.id
    client_id              = aws_cognito_user_pool_client.web.client_id
    region                 = data.aws_region.current.name
    domain                 = aws_cognito_user_pool_domain.main.domain
    authorization_endpoint = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/authorize"
    token_endpoint         = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token"
    userinfo_endpoint      = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/userinfo"
  })

  tags = {
    Name = "Cognito configuration"
  }
}

# SSM Parameter Store: Store API configuration
resource "aws_ssm_parameter" "api_config" {
  name        = "/hojadevida/${var.environment}/api"
  description = "API configuration for ${var.environment} environment"
  type        = "String"
  tier        = var.ssm_parameter_tier

  # This will be set after API Gateway is created
  # For now, use a placeholder
  value = jsonencode({
    endpoint = "https://api.hojadevida.local"
    stage    = var.environment
    version  = "v1"
  })

  tags = {
    Name = "API configuration"
  }
}

# SSM Parameter Store: Store Lambda configuration
resource "aws_ssm_parameter" "lambda_config" {
  name        = "/hojadevida/${var.environment}/lambda"
  description = "Lambda configuration for ${var.environment} environment"
  type        = "String"
  tier        = var.ssm_parameter_tier

  value = jsonencode({
    bedrock_model_id    = var.bedrock_model_id
    bedrock_max_tokens  = var.bedrock_max_tokens
    bedrock_temperature = var.bedrock_temperature
  })

  tags = {
    Name = "Lambda configuration"
  }
}

# SSM Parameter Store: Store Bedrock configuration
resource "aws_ssm_parameter" "bedrock_config" {
  name        = "/hojadevida/${var.environment}/bedrock"
  description = "Bedrock configuration for ${var.environment} environment"
  type        = "String"
  tier        = var.ssm_parameter_tier

  value = jsonencode({
    model_id           = var.bedrock_model_id
    max_tokens         = var.bedrock_max_tokens
    temperature        = var.bedrock_temperature
    estimated_tokens   = var.bedrock_token_estimate
    estimated_cost_usd = (var.bedrock_token_estimate * 0.25) / 1000000 # Haiku: $0.25 per 1M input tokens
  })

  tags = {
    Name = "Bedrock configuration"
  }
}
