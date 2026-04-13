# Phase 1.9 Update: Initial Account Setup Complete

## Summary

✅ **COMPLETED**: CloudFormation stack deployment with all account-level infrastructure.

The single `initial-account-setup.yaml` stack now creates:
- GitHub OIDC Provider + Role for CI/CD authentication
- ECR Repository for frontend Docker images
- Terraform state S3 buckets (separate dev & prod)
- Terraform state DynamoDB lock tables (separate dev & prod)
- API Gateway endpoints (separate dev & prod)

---

## Resources Created

### GitHub OIDC

| Resource | Value |
|----------|-------|
| **Provider ARN** | `arn:aws:iam::871696174477:oidc-provider/token.actions.githubusercontent.com` |
| **Role ARN** | `arn:aws:iam::871696174477:role/GitHubOIDCRole` |
| **Role Policy** | `AdministratorAccess` |

### Terraform State Infrastructure

| Environment | S3 Bucket | DynamoDB Lock Table |
|-------------|-----------|---------------------|
| **Dev** | `hojadevida-terraform-state-871696174477-dev` | `hojadevida-terraform-locks-871696174477-dev` |
| **Prod** | `hojadevida-terraform-state-871696174477-prod` | `hojadevida-terraform-locks-871696174477-prod` |

**Key Features:**
- ✅ Separate buckets per environment (isolation + parallel deploys)
- ✅ S3 versioning enabled on both buckets
- ✅ AES256 encryption on both buckets
- ✅ Public access blocked on both buckets
- ✅ DynamoDB on-demand billing (pay-per-request)
- ✅ No state sharing between environments

### API Gateway Endpoints

| Environment | API Gateway ID | Endpoint URL |
|-------------|---|---|
| **Dev** | `fu36x4ekc6` | `https://fu36x4ekc6.execute-api.us-east-1.amazonaws.com/dev` |
| **Prod** | `b8puvctj6j` | `https://b8puvctj6j.execute-api.us-east-1.amazonaws.com/prod` |

**Key Features:**
- ✅ Separate API Gateways per environment
- ✅ HTTP protocol (not REST)
- ✅ Separate stages (dev vs prod)
- ✅ Auto-deploy enabled on both stages

### ECR Repository

| Property | Value |
|----------|-------|
| **Name** | `hojadevida-frontend` |
| **URI** | `871696174477.dkr.ecr.us-east-1.amazonaws.com/hojadevida-frontend` |
| **Image Scanning** | Enabled (on push) |

---

## GitHub Secrets Configured

All secrets are set at the repository level and will be available to workflows:

```
✅ AWS_ROLE_ARN                 → arn:aws:iam::871696174477:role/GitHubOIDCRole
✅ API_URL_DEV                  → https://fu36x4ekc6.execute-api.us-east-1.amazonaws.com/dev
✅ COGNITO_POOL_ID_DEV          → placeholder-update-after-deploy
✅ COGNITO_CLIENT_ID_DEV        → placeholder-update-after-deploy
✅ API_URL_PROD                 → https://b8puvctj6j.execute-api.us-east-1.amazonaws.com/prod
✅ COGNITO_POOL_ID_PROD         → placeholder-update-after-deploy
✅ COGNITO_CLIENT_ID_PROD       → placeholder-update-after-deploy
```

**Action Required:** After first Terraform deployment (Phase 1.10), update:
- `COGNITO_POOL_ID_DEV` with actual Cognito pool ID
- `COGNITO_CLIENT_ID_DEV` with actual Cognito client ID
- `COGNITO_POOL_ID_PROD` with actual Cognito pool ID
- `COGNITO_CLIENT_ID_PROD` with actual Cognito client ID

---

## Architecture Decisions Implemented

### 1. **Separate State Buckets per Environment** (Recommended)
- **Why:** True isolation, parallel deploys, no race conditions on DynamoDB locks
- **Alternative rejected:** Shared bucket with key-based separation (too risky)
- **Risk mitigation:** GitHub role can restrict to specific bucket ARNs in the future

### 2. **Separate API Gateways per Environment** (Recommended)
- **Why:** Independent quotas, throttling limits, and deployment cycles
- **Alternative rejected:** Single APIGW with stages (shared throttling, less isolation)
- **Cost:** ~$7/mo (two APIGW) vs $3.50/mo (one APIGW) — acceptable for production safety

### 3. **HTTP API vs REST API**
- **Why:** HTTP API is simpler, cheaper, and sufficient for our use case
- **Features:** Integrations with Lambda, WebSocket support, built-in CORS

### 4. **Administrator Access for GitHub Role** (Temporary)
- **Why:** Simplified setup to unblock Phase 1.10
- **Action required:** Replace with least-privilege policy post-Phase-1
- **Policy should allow:** S3 (terraform state), DynamoDB (locks), and service-specific permissions

---

## What This Enables

✅ **Terraform workflows can now:**
- Use separate state files (dev/prod) without manual S3 management
- Use DynamoDB-based state locking to prevent concurrent modifications
- Reference Terraform state outputs via CloudFormation Exports (Hojadevida-DevApiEndpoint, etc.)

✅ **GitHub Actions can now:**
- Assume the GitHubOIDCRole using OIDC token (no long-lived credentials)
- Deploy infrastructure changes automatically on `main` → dev, `prod` → prod
- Push Docker images to ECR for frontend deployments

✅ **Manual deployments can:**
- Use the API Gateway endpoints for testing
- Verify Cognito integration once deployed

---

## Next Steps

### Phase 1.10 (Cleanup & Documentation)
1. Deploy Terraform infrastructure (dev + prod)
2. Update GitHub secrets with Cognito pool/client IDs from Terraform outputs
3. Verify API Gateway integration works end-to-end
4. Decommission old CloudFormation stacks (network-setup.yaml, frontend-setup.yaml)
5. Update README with Terraform deployment instructions

### Post-Phase-1 (Security Hardening)
1. Replace `AdministratorAccess` with least-privilege policy
2. Add resource-based restrictions to GitHub role
3. Enable CloudTrail logging for all Terraform operations
4. Set up budget alerts for AWS costs

---

## Git Commit

```
ada25a6 chore: Update initial-account-setup.yaml with Terraform state buckets, DynamoDB locks, and API Gateways
```

Files modified:
- `infrastructure/initial-account-setup.yaml` (177 lines added/modified)
