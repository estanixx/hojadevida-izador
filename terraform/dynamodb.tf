# ============================================================================
# DynamoDB Resources for Hojadevida-izador Application
# ============================================================================
#
# This file defines all DynamoDB tables needed for:
# - CVs Table: Main table storing CV metadata with GSI for date-based queries
# - Terraform Locks Table: State locking mechanism for safe concurrent operations
#
# Billing mode is configurable (PAY_PER_REQUEST for dev, PROVISIONED for prod)
# Point-in-time recovery is disabled per user requirements
# ============================================================================

# ============================================================================
# Main CVs Table
# ============================================================================
# Primary table for storing CV metadata and document references.
# Partition key: userId | Sort key: cvId
# Enables efficient queries for all CVs by user and by creation date
#
# Design rationale:
# - PAY_PER_REQUEST provides cost efficiency for variable workloads
# - GSI on userId + createdAt enables date-based filtering (Phase 2+)
# - All attributes projected to avoid additional queries
# - TTL disabled (CVs are user-managed, not auto-expiring)
# - PITR disabled per requirement, but can be enabled in production

resource "aws_dynamodb_table" "cvs" {
  name         = "${var.app_name}-cvs-${var.environment}"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "userId"
  range_key    = "cvId"

  # ========================================================================
  # Attributes
  # ========================================================================
  # Define all attributes referenced in keys (hash/range and GSI keys)
  # Additional attributes can be stored without declaration

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "cvId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # ========================================================================
  # Global Secondary Index: userIdCreatedAtGSI
  # ========================================================================
  # Enables queries like:
  # - Get all CVs for a user ordered by creation date
  # - Find CVs created within a date range
  # - Support for pagination and sorting by date
  # ALL projection includes all attributes to avoid fetches

  global_secondary_index {
    name            = "userIdCreatedAtGSI"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # ========================================================================
  # Tags
  # ========================================================================
  # Applied automatically via provider default_tags
  # Additional tags for clarity

  tags = {
    Name        = "${var.app_name}-cvs-table"
    Description = "Stores CV metadata and document references"
    Component   = "DataLayer"
  }
}

# ============================================================================
# DynamoDB Table for Terraform State Locks
# ============================================================================
# NOTE: Terraform locks table is managed by CloudFormation (initial-account-setup.yaml)
# to enable account-level management independent of Terraform state.
# This ensures Terraform can always access its lock mechanism even during infrastructure changes.
#
# CloudFormation-managed resource:
# - DynamoDB Table: hojadevida-terraform-locks-{account-id}-{env}
# - Accessed via: -backend-config flags in terraform init

