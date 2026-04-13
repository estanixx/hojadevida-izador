# ============================================================================
# DynamoDB Resources for Hojadevida-izador Application
# ============================================================================
#
# NOTE: DynamoDB tables are now managed by AWS SAM (backend/template.yaml)
# This ensures the backend data layer is tightly coupled with Lambda functions
# and API Gateway definitions.
#
# SAM-managed resources:
# - CVs Table: Stores CV metadata with GSI for date-based queries
# - DynamoDB configuration (billing mode, TTL, PITR settings) in backend/template.yaml
#
# Terraform manages: Infrastructure layer (VPC, ECS, ALB, monitoring)

