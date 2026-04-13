# Pre-Deployment Setup Guide

This guide walks through all steps needed to deploy hojadevida-izador infrastructure for the first time.

**Estimated time: 15 minutes**

---

## 1. Deploy Initial Account Setup (One-Time)

This CloudFormation stack creates:
- GitHub OIDC Provider (for GitHub Actions authentication)
- GitHub OIDC Role + Permissions Boundary
- ECR Repository for frontend Docker images

```bash
cd infrastructure

aws cloudformation deploy \
  --template-file initial-account-setup.yaml \
  --stack-name hojadevida-initial-account-setup \
  --parameter-overrides \
    GitHubOrg=estanixx \
    GitHubRepo=hojadevida-izador \
    ECRRepositoryName=hojadevida-frontend \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1 \
  --no-fail-on-empty-changeset
```

**Verify it worked:**
```bash
aws iam list-open-id-connect-providers
aws ecr describe-repositories --query 'repositories[].repositoryUri'
aws iam get-role --role-name GitHubOIDCRole
```

**Get the role ARN** (you'll need this for GitHub secrets):
```bash
aws iam get-role \
  --role-name GitHubOIDCRole \
  --query 'Role.Arn' \
  --output text
```

Copy this ARN — you'll use it in Step 3 below.

---

## 2. Create Terraform State Infrastructure (One-Time)

Terraform needs separate S3 buckets and DynamoDB lock tables for each environment.

```bash
ACCOUNT_ID="871696174477"
REGION="us-east-1"

for ENV in dev prod; do
  BUCKET="hojadevida-terraform-state-${ACCOUNT_ID}-${ENV}"
  LOCKS_TABLE="hojadevida-terraform-locks-${ACCOUNT_ID}-${ENV}"
  
  echo "=== Creating state infrastructure for ${ENV} ==="
  
  # Create S3 bucket
  echo "Creating S3 bucket: ${BUCKET}"
  aws s3api create-bucket \
    --bucket ${BUCKET} \
    --region ${REGION} \
    $([ "${REGION}" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=${REGION}") || true
  
  # Enable versioning
  echo "Enabling versioning..."
  aws s3api put-bucket-versioning \
    --bucket ${BUCKET} \
    --versioning-configuration Status=Enabled
  
  # Enable encryption
  echo "Enabling encryption..."
  aws s3api put-bucket-encryption \
    --bucket ${BUCKET} \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
  
  # Block public access
  echo "Blocking public access..."
  aws s3api put-public-access-block \
    --bucket ${BUCKET} \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  
  # Create DynamoDB locks table
  echo "Creating DynamoDB locks table: ${LOCKS_TABLE}"
  aws dynamodb create-table \
    --table-name ${LOCKS_TABLE} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ${REGION} || true
  
  echo "✅ Created state infrastructure for ${ENV}"
done

echo ""
echo "✅ All state buckets and lock tables created!"
echo ""
echo "Buckets:"
aws s3 ls | grep hojadevida-terraform-state
echo ""
echo "DynamoDB tables:"
aws dynamodb list-tables --query 'TableNames[?contains(@, `hojadevida-terraform-locks`)]' --output text
```

---

## 3. Set GitHub Secrets

These secrets are used by the GitHub Actions workflows to deploy infrastructure.

### Using GitHub CLI (Recommended)

```bash
# Get the OIDC role ARN from Step 1
OIDC_ROLE_ARN="arn:aws:iam::871696174477:role/GitHubOIDCRole"

# Set secrets
gh secret set AWS_ROLE_ARN --body "${OIDC_ROLE_ARN}"

# Temporary placeholders (will update after first deployment)
gh secret set API_URL_DEV --body "https://placeholder"
gh secret set COGNITO_POOL_ID_DEV --body "placeholder"
gh secret set COGNITO_CLIENT_ID_DEV --body "placeholder"

# Prod secrets (only needed if deploying prod)
gh secret set API_URL_PROD --body "https://placeholder"
gh secret set COGNITO_POOL_ID_PROD --body "placeholder"
gh secret set COGNITO_CLIENT_ID_PROD --body "placeholder"

# Verify
gh secret list
```

### Or Using GitHub Web UI

1. Go to: **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Add each secret:
   - `AWS_ROLE_ARN` = (from Step 1)
   - `API_URL_DEV` = placeholder
   - `COGNITO_POOL_ID_DEV` = placeholder
   - `COGNITO_CLIENT_ID_DEV` = placeholder
   - (and prod versions if needed)

---

## 4. Deploy Dev Infrastructure (Manually First Time)

Before the workflows can run, deploy dev infrastructure manually to populate the terraform state.

```bash
cd terraform

# Initialize with dev backend
terraform init \
  -backend-config="bucket=hojadevida-terraform-state-871696174477-dev" \
  -backend-config="key=hojadevida.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=hojadevida-terraform-locks-871696174477-dev" \
  -backend-config="encrypt=true"

# Validate
terraform validate

# Plan
terraform plan -var-file=terraform.tfvars -out=tfplan

# Review the plan (output shows all resources to create)
terraform show tfplan | head -50

# Apply (create all resources)
terraform apply -var-file=terraform.tfvars -auto-approve tfplan
```

**This will take 3-5 minutes.** Watch the output:

```
aws_vpc.main: Creating...
aws_dynamodb_table.cvs: Creating...
aws_cognito_user_pool.main: Creating...
... (many resources)
Apply complete! Resources: 84 added.
```

**Verify deployment:**
```bash
aws ec2 describe-vpcs --filters Name=tag:Name,Values=hojadevida-vpc
aws dynamodb describe-table --table-name hojadevida-cvs-dev
aws cognito-idp describe-user-pool --user-pool-id us-east-1_* --region us-east-1 2>/dev/null || echo "Check AWS Console"
```

---

## 5. Update GitHub Secrets with Real Values

After dev deployment, get the actual values and update GitHub secrets.

```bash
cd terraform

# Get outputs
terraform output -json > outputs.json

# Extract values
COGNITO_POOL_ID=$(terraform output -raw cognito_user_pool_id)
COGNITO_CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id)
API_GATEWAY_ID=$(terraform output -raw api_gateway_id)

# Construct API URL
API_URL="https://${API_GATEWAY_ID}.execute-api.us-east-1.amazonaws.com"

echo "Cognito Pool ID: ${COGNITO_POOL_ID}"
echo "Cognito Client ID: ${COGNITO_CLIENT_ID}"
echo "API URL: ${API_URL}"

# Update secrets
gh secret set API_URL_DEV --body "${API_URL}"
gh secret set COGNITO_POOL_ID_DEV --body "${COGNITO_POOL_ID}"
gh secret set COGNITO_CLIENT_ID_DEV --body "${COGNITO_CLIENT_ID}"

# Verify
gh secret list
```

---

## 6. Add GitHub Branch Protection Rules

This prevents direct pushes to prod and requires PRs with reviews.

### Via GitHub CLI

```bash
# Add rule for prod branch
gh api repos/estanixx/hojadevida-izador/branches/prod/protection \
  --method=PUT \
  -f require_code_owner_reviews=true \
  -f required_approving_review_count=1 \
  -f require_status_checks=true \
  -f status_checks='["terraform-plan", "security-checks"]' \
  -f enforce_admins=false \
  -f allow_force_pushes=false \
  -f allow_deletions=false \
  -f required_linear_history=false

echo "✅ Branch protection rules applied to prod"
```

### Or Via GitHub Web UI

1. Go to: **Settings → Branches**
2. Click **Add rule**
3. Branch name pattern: `prod`
4. Enable:
   - ✅ **Require pull request reviews before merging**
     - Required approving reviews: `1`
   - ✅ **Require status checks to pass before merging**
     - Select: `terraform-plan`, `security-checks`
   - ✅ **Require branches to be up to date before merging**
   - ✅ **Restrict who can push to matching branches**
     - Allow admins only
   - ❌ Uncheck **Allow force pushes**
   - ❌ Uncheck **Allow deletions**
4. Click **Create**

---

## 7. Test Workflows

Now you're ready to test the GitHub Actions workflows.

### Test 1: Dev Auto-Deployment

```bash
git checkout main
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger GitHub Actions workflow"
git push origin main
```

Go to GitHub → **Actions** tab, watch the workflow run:
- `determine-env` → dev ✅
- `terraform-deploy` → should be a no-op (same config) ✅
- `backend-deploy` → updates Lambda code ✅
- `frontend-deploy` → builds and pushes Docker image ✅
- `verify-deployment` → checks ECS health ✅

**Expected time: 5-10 minutes**

### Test 2: PR Plan Comment

```bash
git checkout -b test/feature
echo "# Feature test" >> README.md
git add README.md
git commit -m "feat: test PR plan comment"
git push origin test/feature
```

Go to GitHub and create PR to `main`

Watch: **Actions** → `plan.yml` runs
- `determine-env` → dev ✅
- `terraform-plan` → runs plan (should be no-op) ✅
- `security-checks` → runs tfsec ✅
- Comment appears on PR with plan output ✅

### Test 3: Prod Branch Protection

Try to push directly to prod (should fail):

```bash
git push origin main:prod
```

**Expected result:**
```
remote: error: GH006: Protected branch rule violations
remote: At least 1 approving review is required
```

✅ Branch protection working

### Test 4: Prod PR Workflow

Create a proper PR from main to prod:

```bash
gh pr create --base prod --head main --title "Deploy to production" --body "Ready to deploy to prod"
```

Watch workflow:
- `determine-env` → prod ✅
- `terraform-plan` → runs with terraform.prod.tfvars ✅
- Plan comment shows prod config ✅
- Requires approval + checks pass

---

## Troubleshooting

### "Error acquiring the state lock"

The Terraform lock is stuck. Clear it:

```bash
ENV="dev"  # or "prod"
ACCOUNT_ID="871696174477"
TABLE="hojadevida-terraform-locks-${ACCOUNT_ID}-${ENV}"

aws dynamodb scan --table-name ${TABLE} --region us-east-1
# Note the LockID value
aws dynamodb delete-item --table-name ${TABLE} \
  --key '{"LockID": {"S": "hojadevida-terraform-state-871696174477-dev/hojadevida.tfstate"}}' \
  --region us-east-1
```

### "Invalid backend configuration" during init

Verify the bucket names are correct:

```bash
aws s3 ls | grep hojadevida-terraform-state
# Should show both dev and prod buckets
```

### "AWS credential issue" in workflow

Verify:
1. `AWS_ROLE_ARN` secret is set correctly
2. GitHub OIDC role exists:
   ```bash
   aws iam get-role --role-name GitHubOIDCRole
   ```
3. Trust relationship includes your repo:
   ```bash
   aws iam get-role --role-name GitHubOIDCRole --query 'Role.AssumeRolePolicyDocument' | jq .
   ```

### "ECR repository does not exist"

Create it via initial-account-setup CloudFormation:

```bash
cd infrastructure
aws cloudformation update-stack \
  --stack-name hojadevida-initial-account-setup \
  --template-body file://initial-account-setup.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

---

## Quick Reference

| Step | Command | Notes |
|------|---------|-------|
| Deploy CloudFormation | `aws cloudformation deploy --template-file initial-account-setup.yaml ...` | One-time |
| Create state buckets | `for ENV in dev prod; do ... aws s3api create-bucket ... done` | One-time |
| Set GitHub secrets | `gh secret set AWS_ROLE_ARN --body "..."` | Multiple secrets |
| Deploy terraform dev | `terraform init -backend-config=... && terraform apply -var-file=terraform.tfvars` | Manual first time |
| Update secrets | `terraform output -json \| extract values` | After first deployment |
| Add branch rules | `gh api repos/.../branches/prod/protection --method=PUT ...` | Via CLI or web |
| Test dev deployment | `git push origin main` | Workflow should run |
| Test PR comment | `gh pr create --base main` | Workflow should run |
| Test prod protection | `git push origin main:prod` | Should fail |

---

## What's Next

After testing all workflows successfully:

1. Deploy prod infrastructure (optional):
   ```bash
   terraform init -backend-config="bucket=hojadevida-terraform-state-871696174477-prod" ...
   terraform apply -var-file=terraform.prod.tfvars
   ```

2. Update prod GitHub secrets with real values

3. Proceed to **Phase 1.10: Cleanup & Documentation**

Good luck! 🚀
