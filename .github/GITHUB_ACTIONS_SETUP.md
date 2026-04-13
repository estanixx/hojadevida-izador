# GitHub Actions Setup Guide

This document explains the GitHub Actions workflows and required secrets/variables for Phase 1.9.

## Branch Structure

- **main** → dev environment (auto-deploy on push)
- **prod** → production environment (PR-only, requires approval)

## Workflows

### 1. `deploy.yml` — Deploy Infrastructure & Application

**Triggers:**
- Push to `main` (dev) or `prod` branches
- Manual dispatch (`workflow_dispatch`)
- Only if changes in: `terraform/`, `backend/`, `frontend/`, or `.github/workflows/`

**Jobs:**
1. **determine-env** — Determine environment (dev/prod) from branch
2. **terraform-deploy** — Initialize and deploy Terraform infrastructure
3. **backend-deploy** — Build and deploy Lambda functions
4. **frontend-deploy** — Build Docker image, push to ECR, update ECS
5. **verify-deployment** — Check API Gateway, ECS service health

**Environment Protection:**
- Requires `id-token: write` for AWS OIDC
- Uses GitHub Environments for branch-specific approval gates (optional)

---

### 2. `plan.yml` — Terraform Plan on Pull Requests

**Triggers:**
- PR to `main` or `prod` branches
- Only if changes in: `terraform/` or `.github/workflows/`

**Jobs:**
1. **determine-env** — Determine target environment from PR base branch
2. **terraform-plan** — Run `terraform plan`, comment results on PR
3. **check-prod-protection** — Verify PR is from `main` → `prod` (not direct push)
4. **security-checks** — Run tfsec for security validation

**PR Comments:**
- Posts `terraform plan` output on PR for review
- Shows what resources will be created/modified/destroyed

---

### 3. `protect-prod.yml` — Enforce Branch Protection

**Triggers:**
- Direct push to `prod` branch

**Behavior:**
- **REJECTS** the push
- Shows message: "Direct pushes to prod are forbidden!"
- Only PRs from `main` → `prod` are allowed

---

## Required GitHub Secrets & Variables

### Repository Secrets (Settings → Secrets and variables → Actions)

These are sensitive values that should NOT be in code:

#### AWS Authentication
```
AWS_ROLE_ARN
  Description: ARN of GitHub OIDC role in AWS
  Format: arn:aws:iam::871696174477:role/github-oidc-hojadevida-izador
  Created by: terraform/iam.tf (aws_iam_role.github_oidc)
```

#### Dev Environment Secrets
```
API_URL_DEV
  Description: API Gateway HTTP endpoint (dev)
  Format: https://5uuobdjmp2.execute-api.us-east-1.amazonaws.com
  Source: terraform output or AWS Console

COGNITO_POOL_ID_DEV
  Description: Cognito User Pool ID (dev)
  Format: us-east-1_vTyZgjewH
  Source: terraform output

COGNITO_CLIENT_ID_DEV
  Description: Cognito User Pool Client ID (dev)
  Format: 5csgog5d56nnk62ggfg94j6d5m
  Source: terraform output
```

#### Production Environment Secrets
```
API_URL_PROD
  Description: API Gateway HTTP endpoint (prod)

COGNITO_POOL_ID_PROD
  Description: Cognito User Pool ID (prod)

COGNITO_CLIENT_ID_PROD
  Description: Cognito User Pool Client ID (prod)
```

### Repository Variables (Settings → Secrets and variables → Variables)

These are non-sensitive values that can be in code or GitHub:

```
AWS_REGION = "us-east-1"
TF_VERSION = "1.14.8"
```

---

## Setup Steps

### 1. Create AWS OIDC Role

This is already created by `terraform/iam.tf` (Phase 1.1), but verify:

```bash
aws iam list-roles \
  --query "Roles[?contains(RoleName, 'github-oidc')].Arn" \
  --output text
```

Expected: `arn:aws:iam::871696174477:role/github-oidc-hojadevida-izador`

### 2. Get AWS Role ARN

```bash
aws iam get-role --role-name github-oidc-hojadevida-izador --query 'Role.Arn' --output text
```

### 3. Add GitHub Secrets

In GitHub repo settings:

```
Settings → Secrets and variables → Actions → New repository secret
```

Add:
- `AWS_ROLE_ARN` = (from step 2)
- `API_URL_DEV` = Your dev API Gateway URL
- `COGNITO_POOL_ID_DEV` = Your dev Cognito pool ID
- `COGNITO_CLIENT_ID_DEV` = Your dev Cognito client ID
- `API_URL_PROD` = Your prod API Gateway URL (when ready)
- `COGNITO_POOL_ID_PROD` = Your prod Cognito pool ID (when ready)
- `COGNITO_CLIENT_ID_PROD` = Your prod Cognito client ID (when ready)

### 4. (Optional) Add GitHub Branch Protection

In GitHub repo settings:

```
Settings → Branches → Add rule
```

For `prod` branch:
- ✅ Require pull request reviews before merging
- ✅ Require code owner review
- ✅ Require approval from ${{ github.event.pull_request.base.repo.owner }}
- ✅ Restrict who can push to matching branches (only admins)
- ✅ Require status checks to pass (select `plan.yml` jobs)

For `main` branch (optional):
- ✅ Require PR reviews (1-2 approvals)
- ✅ Require status checks to pass

---

## Workflow Behavior

### On Push to `main` (dev)

1. Determine environment = dev
2. Run `terraform apply -var-file=terraform/terraform.tfvars`
3. Build & deploy Lambda functions
4. Build Docker image, push to ECR
5. Update ECS service with new image
6. Verify deployment health

**Result**: Dev environment fully deployed

### On Push to `prod` (blocked)

`protect-prod.yml` immediately rejects with error:
```
❌ Direct pushes to 'prod' branch are FORBIDDEN!
Use pull requests instead.
```

### On PR to `main` (from any branch)

1. Determine environment = dev
2. Run `terraform plan -var-file=terraform/terraform.tfvars`
3. Comment plan output on PR
4. Run security checks (tfsec)

**Result**: Reviewers can see what changes before merge

### On PR to `prod` (from `main` only)

1. **Check**: Is PR from `main` → `prod`? YES ✅
2. Run `terraform plan -var-file=terraform.prod.tfvars`
3. Comment plan output on PR
4. Run security checks

**Result**: Reviewers see production changes before approval

### On PR to `prod` (from any other branch)

1. **Check**: Is PR from `main` → `prod`? NO ❌
2. Fail with error: "Only PRs from main to prod allowed"

**Result**: Prevents accidental prod deployments from feature branches

---

## Troubleshooting

### "Error acquiring the state lock"

Terraform state is locked. Clean up:

```bash
cd terraform
aws dynamodb delete-item \
  --table-name hojadevida-terraform-locks-871696174477-dev \
  --key '{"LockID": {"S": "hojadevida-terraform-state-871696174477-dev/hojadevida.tfstate"}}' \
  --region us-east-1
```

### Lambda deployment fails: "Function not found"

Check function names match in workflow:
- Expected: `hojadevida-listCvs-dev`, `hojadevida-generateCv-dev`
- Update in `deploy.yml` if changed

### ECR push fails: "Repository does not exist"

ECR repository must be created by Terraform first:
```bash
cd terraform
terraform apply -var-file=terraform.tfvars
```

### "AWS credentials not found"

Verify:
1. `AWS_ROLE_ARN` secret is set
2. GitHub OIDC trust policy includes your repo
3. Run workflow manually first: `workflow_dispatch`

---

## Security Best Practices

1. **Secrets Rotation**: Rotate AWS credentials every 90 days
2. **Branch Protection**: Always require PR approval before merging to prod
3. **Code Owners**: Set `.github/CODEOWNERS` for required reviews
4. **Audit Logs**: Review GitHub Actions logs for suspicious activity
5. **Least Privilege**: AWS role should only have permissions for Terraform actions

---

## Next Steps

After Phase 1.9 is complete:

- [ ] Test `deploy.yml` by pushing to `main`
- [ ] Verify Lambda functions are updated
- [ ] Check ECS service is running with new image
- [ ] Test `plan.yml` by creating a PR to `main`
- [ ] Verify plan comment appears on PR
- [ ] Create PR from `main` → `prod`
- [ ] Verify prod protection rejects direct pushes
- [ ] Merge PR after approval to deploy to prod

Phase 1.10: Cleanup & Documentation
