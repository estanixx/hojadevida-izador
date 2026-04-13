# ============================================================================
# S3 Resources for Hojadevida-izador Application
# ============================================================================
#
# This file defines all S3 buckets needed for:
# - CVs Bucket: Stores generated CV documents with encryption and lifecycle
# - Terraform State Bucket: Stores Terraform state with versioning and encryption
#
# All buckets enforce encryption, block public access, and implement
# lifecycle policies for cost optimization and compliance.
# ============================================================================

# ============================================================================
# CVs S3 Bucket
# ============================================================================
# Primary storage for all generated CV documents.
# Enforces AES256 encryption and denies unencrypted uploads via bucket policy.
#
# Design rationale:
# - Account-scoped naming prevents collisions in multi-account setup
# - Bucket versioning enables recovery from accidental deletions
# - AES256 encryption protects PII (user CVs contain personal data)
# - Lifecycle policy: noncurrent versions expire after 90 days (configurable)
# - Glacier transition: automatic archival after 365 days for long-term retention

resource "aws_s3_bucket" "cvs" {
  bucket = "${var.app_name}-cvs-${data.aws_caller_identity.current.account_id}-${var.environment}"

  tags = {
    Name        = "${var.app_name}-cvs-bucket"
    Description = "Stores generated CV documents"
    Component   = "Storage"
  }
}

# ========================================================================
# Block All Public Access
# ========================================================================
# Prevents accidental public exposure of user CV documents
# All four block settings enabled (ACLs, public policies, etc.)

resource "aws_s3_bucket_public_access_block" "cvs" {
  bucket = aws_s3_bucket.cvs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================================================
# Versioning Configuration
# ========================================================================
# Maintains history of all CV documents for recovery and audit trails
# Supports rollback if a CV is accidentally overwritten

resource "aws_s3_bucket_versioning" "cvs" {
  bucket = aws_s3_bucket.cvs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ========================================================================
# Server-Side Encryption Configuration
# ========================================================================
# Encrypts all CVs at rest using AES256 (AWS managed keys)
# Can be upgraded to KMS customer-managed keys for prod if needed

resource "aws_s3_bucket_server_side_encryption_configuration" "cvs" {
  bucket = aws_s3_bucket.cvs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ========================================================================
# Bucket Policy: Enforce Encrypted Uploads
# ========================================================================
# Denies s3:PutObject if request lacks x-amz-server-side-encryption header
# or if the encryption is not AES256. Prevents unencrypted uploads.
#
# Policy logic:
# - Condition: x-amz-server-side-encryption header must be present
# - Condition: Value must be "AES256"
# - Effect: Deny if either condition fails
# - Action: s3:PutObject (prevents unencrypted uploads)

resource "aws_s3_bucket_policy" "cvs" {
  bucket = aws_s3_bucket.cvs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cvs.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })
}

# ========================================================================
# Lifecycle Configuration
# ========================================================================
# Implements two-tier retention:
# 1. Keep noncurrent versions for 90 days (var.s3_lifecycle_retention_days)
# 2. Transition to Glacier storage after 365 days (var.s3_glacier_transition_days)
#
# Benefits:
# - Noncurrent versions auto-deleted: saves storage costs
# - Glacier transition: 90% cheaper for archival CVs (beyond 1 year)
# - Complies with data retention policies

resource "aws_s3_bucket_lifecycle_configuration" "cvs" {
  bucket = aws_s3_bucket.cvs.id

  rule {
    id     = "ExpireNoncurrentVersions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.s3_lifecycle_retention_days
    }
  }

  rule {
    id     = "TransitionToGlacier"
    status = "Enabled"
    filter {}

    transition {
      days          = var.s3_glacier_transition_days
      storage_class = "GLACIER"
    }
  }
}

# ============================================================================
# Terraform State Bucket
# ============================================================================
# NOTE: Terraform state bucket is managed by CloudFormation (initial-account-setup.yaml)
# to enable account-level management independent of Terraform state.
# This ensures Terraform can always access its backend even during infrastructure changes.
#
# CloudFormation-managed resource:
# - S3 Bucket: hojadevida-terraform-state-{account-id}-{env}
# - DynamoDB Lock Table: hojadevida-terraform-locks-{account-id}-{env}
# - Accessed via: -backend-config flags in terraform init

