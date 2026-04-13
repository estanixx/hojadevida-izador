# ============================================================================
# S3 Resources for Hojadevida-izador Application
# ============================================================================
#
# NOTE: S3 buckets for backend (CVs storage) are now managed by AWS SAM (backend/template.yaml)
# This ensures the backend storage layer is tightly coupled with Lambda functions
# that read/write to these buckets.
#
# SAM-managed resources:
# - CVs Bucket: Stores generated CV documents with encryption and lifecycle
# - S3 configuration (versioning, lifecycle, encryption) in backend/template.yaml
#
# Terraform manages: Infrastructure layer (VPC, ECS, ALB, monitoring)
#
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

