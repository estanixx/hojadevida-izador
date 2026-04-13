# ============================================================================
# IAM Roles and Policies for Hojadevida-izador Application
# ============================================================================
#
# This file defines all IAM roles and policies needed for:
# - Lambda functions (CV generation, PDF processing)
# - ECS tasks (frontend serving)
# - GitHub Actions OIDC federation (CI/CD automation)
# - Permission boundaries (security guardrails)
#
# Resource ARNs are referenced via variables that will be defined in
# dynamodb.tf, s3.tf, and other resource files.
# ============================================================================

# ============================================================================
# Lambda Execution Role
# ============================================================================
# Service role that Lambda functions assume to access AWS resources.
# Allows interaction with DynamoDB (CVs table), S3 (storage), Bedrock (AI),
# CloudWatch (logging), and SSM Parameter Store (configuration).

resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.app_name}-lambda-execution-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  permissions_boundary = aws_iam_policy.permission_boundary.arn

  tags = {
    Name        = "${var.app_name}-lambda-execution-role"
    Description = "Execution role for Lambda functions"
  }
}

# ============================================================================
# Lambda Execution Policy
# ============================================================================
# Inline policy that grants Lambda functions permissions to:
# - Read/write CV metadata in DynamoDB
# - Store/retrieve CV documents in S3
# - Invoke Bedrock models for CV generation
# - Write logs to CloudWatch
# - Retrieve configuration from SSM Parameter Store

resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${var.app_name}-lambda-execution-policy-${var.environment}"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ======================================================================
      # DynamoDB Permissions
      # ======================================================================
      {
        Sid    = "DynamoDBCVsTable"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = var.dynamodb_cvs_table_arn
      },
      # ======================================================================
      # S3 Permissions
      # ======================================================================
      {
        Sid    = "S3CVsBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${var.s3_cvs_bucket_arn}/*"
      },
      # ======================================================================
      # Bedrock Permissions
      # ======================================================================
      # Allow invocation of all Bedrock models for CV generation
      {
        Sid    = "BedrockInvokeModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*"
      },
      # ======================================================================
      # CloudWatch Logs Permissions
      # ======================================================================
      # Allow creation and writing to CloudWatch log groups for Lambda logging
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.app_name}*:*"
      },
      # ======================================================================
      # SSM Parameter Store Permissions
      # ======================================================================
      # Allow retrieval of configuration parameters
      {
        Sid    = "SSMParameterStore"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.app_name}/*"
      }
    ]
  })
}

# ============================================================================
# ECS Task Execution Role
# ============================================================================
# Service role that ECS uses to pull container images from ECR and push logs
# to CloudWatch. Uses AWS managed policy for standard ECS task execution.

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-ecs-task-execution-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  permissions_boundary = aws_iam_policy.permission_boundary.arn

  tags = {
    Name        = "${var.app_name}-ecs-task-execution-role"
    Description = "Execution role for ECS tasks (ECR, CloudWatch access)"
  }
}

# Attach AWS managed policy for ECS task execution (ECR access, CloudWatch logs)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================================
# ECS Task Role
# ============================================================================
# Service role that the ECS container assumes at runtime. Allows the
# application to access AWS resources (S3 for frontend assets, etc.).

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-ecs-task-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  permissions_boundary = aws_iam_policy.permission_boundary.arn

  tags = {
    Name        = "${var.app_name}-ecs-task-role"
    Description = "Task role for ECS container application runtime"
  }
}

# ============================================================================
# ECS Task Role Policy
# ============================================================================
# Inline policy granting ECS tasks permissions to access S3 for frontend assets.

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "${var.app_name}-ecs-task-role-policy-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3FrontendAssets"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.s3_cvs_bucket_arn}/*"
      }
    ]
  })
}

# ============================================================================
# GitHub OIDC Provider
# ============================================================================
# Federated identity provider for GitHub Actions to assume AWS roles without
# long-lived credentials. Establishes trust relationship with GitHub's OIDC endpoint.

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "${var.app_name}-github-oidc-provider"
    Description = "GitHub Actions OIDC provider for CI/CD"
  }
}

# ============================================================================
# GitHub OIDC Role
# ============================================================================
# IAM role that GitHub Actions assumes via OIDC. Allows CI/CD pipeline to
# deploy Terraform, Lambda functions, and ECS task definitions.

resource "aws_iam_role" "github_oidc_role" {
  name = "${var.app_name}-github-oidc-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  permissions_boundary = aws_iam_policy.permission_boundary.arn

  tags = {
    Name        = "${var.app_name}-github-oidc-role"
    Description = "Role for GitHub Actions OIDC federation"
  }
}

# ============================================================================
# GitHub OIDC Role Policy
# ============================================================================
# Policy granting GitHub Actions permissions to:
# - Manage Terraform state (S3 and DynamoDB locks)
# - Deploy infrastructure (CloudFormation)
# - Update Lambda functions
# - Manage container images (ECR)
# - Deploy ECS task definitions

resource "aws_iam_role_policy" "github_oidc_role_policy" {
  name = "${var.app_name}-github-oidc-role-policy-${var.environment}"
  role = aws_iam_role.github_oidc_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ======================================================================
      # Terraform State Management (S3)
      # ======================================================================
      # Permissions to read and write Terraform state files
      {
        Sid    = "TerraformStateS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_terraform_state_bucket_arn}/*"
      },
      # List bucket for state discovery
      {
        Sid    = "TerraformStateS3ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.s3_terraform_state_bucket_arn
      },
      # ======================================================================
      # Terraform State Locking (DynamoDB)
      # ======================================================================
      # Permissions to manage Terraform locks table
      {
        Sid    = "TerraformStateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:DescribeTable"
        ]
        Resource = var.dynamodb_terraform_locks_table_arn
      },
      # ======================================================================
      # CloudFormation (Full access for now, will be scoped in future phases)
      # ======================================================================
      {
        Sid    = "CloudFormation"
        Effect = "Allow"
        Action = [
          "cloudformation:*"
        ]
        Resource = "*"
      },
      # ======================================================================
      # Lambda Deployment
      # ======================================================================
      # Permissions to update function code and configuration
      {
        Sid    = "LambdaDeploy"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.app_name}*"
      },
      # ======================================================================
      # ECR (Container Image Management)
      # ======================================================================
      # Permissions to authenticate with ECR and push container images
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      # Permissions to manage images in repository
      {
        Sid    = "ECRPushImages"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.app_name}*"
      },
      # ======================================================================
      # ECS Service Deployment
      # ======================================================================
      # Permissions to register task definitions and update services
      {
        Sid    = "ECSManagement"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:service/${var.app_name}*/*",
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/${var.app_name}*:*"
        ]
      },
      # Allow passing IAM role to ECS tasks
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

# ============================================================================
# Permission Boundary Policy
# ============================================================================
# Defines maximum permissions for all IAM roles in this project.
# Acts as a safety guardrail to prevent overprivileged role creation.
#
# Prevents:
# - Creating new users or access keys
# - Modifying trust relationships (assume role policy)
# - Modifying the boundary itself
#
# Allows:
# - All other IAM, AWS service, and resource operations

resource "aws_iam_policy" "permission_boundary" {
  name        = "${var.app_name}-permission-boundary-${var.environment}"
  description = "Permission boundary for all IAM roles in ${var.app_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow all actions except explicitly denied
      {
        Sid    = "AllowMostActions"
        Effect = "Allow"
        Action = [
          "*"
        ]
        Resource = "*"
      },
      # Deny IAM user creation (prevents privilege escalation)
      {
        Sid    = "DenyUserCreation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser"
        ]
        Resource = "*"
      },
      # Deny access key creation (prevents long-lived credential generation)
      {
        Sid    = "DenyAccessKeyCreation"
        Effect = "Deny"
        Action = [
          "iam:CreateAccessKey"
        ]
        Resource = "*"
      },
      # Deny modifying role trust relationships (prevents assume role policy changes)
      {
        Sid    = "DenyAssumeRolePolicyModification"
        Effect = "Deny"
        Action = [
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = "*"
      },
      # Deny modifications to permission boundaries (prevents boundary circumvention)
      {
        Sid    = "DenyPermissionBoundaryModification"
        Effect = "Deny"
        Action = [
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.app_name}-permission-boundary-${var.environment}"
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-permission-boundary"
    Description = "Permission boundary for all roles - security guardrail"
  }
}
