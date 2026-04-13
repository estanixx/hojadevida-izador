# Phase 1.9 Questions & Answers

## 1. Terraform State Consistency Between Dev & Prod

### The Problem You Identified
Good catch! If both dev and prod deploy on commit, we need **separate state files** to avoid conflicts.

### Current Architecture (CORRECT ✅)

```
Dev Environment (main branch)
  └─ Terraform backend:
     ├─ S3 bucket: hojadevida-terraform-state-871696174477-dev
     └─ DynamoDB locks: hojadevida-terraform-locks-871696174477-dev
     └─ Terraform state: hojadevida.tfstate (dev-specific)

Prod Environment (prod branch)
  └─ Terraform backend:
     ├─ S3 bucket: hojadevida-terraform-state-871696174477-prod (NEW)
     └─ DynamoDB locks: hojadevida-terraform-locks-871696174477-prod (NEW)
     └─ Terraform state: hojadevida.tfstate (prod-specific)
```

### How It Works

In `terraform/main.tf`, the backend is configured to use **environment-based bucket names**:

```hcl
backend "s3" {
  bucket         = "hojadevida-terraform-state-${AWS_ACCOUNT_ID}-${ENVIRONMENT}"
  key            = "hojadevida.tfstate"
  region         = "us-east-1"
  dynamodb_table = "hojadevida-terraform-locks-${AWS_ACCOUNT_ID}-${ENVIRONMENT}"
  encrypt        = true
}
```

When `deploy.yml` runs:
- On `main` → uses `terraform/terraform.tfvars` (environment=dev)
- On `prod` → uses `terraform/terraform.prod.tfvars` (environment=prod)

**BUT THERE'S A PROBLEM**: The S3 backend block is **static** — it doesn't interpolate variables. You must manually specify the bucket per environment.

### Solution: Use `-backend-config` During Init

Update `deploy.yml` terraform-deploy job:

```yaml
- name: Terraform Init
  working-directory: terraform
  run: |
    ENV="${{ needs.determine-env.outputs.environment }}"
    terraform init \
      -backend-config="bucket=hojadevida-terraform-state-871696174477-${ENV}" \
      -backend-config="dynamodb_table=hojadevida-terraform-locks-871696174477-${ENV}" \
      -backend-config="key=hojadevida.tfstate" \
      -backend-config="region=us-east-1" \
      -backend-config="encrypt=true"
```

This tells Terraform to use **different backends** per environment at init time.

### State Separation Benefits

✅ **No conflicts** — dev and prod states are isolated
✅ **Independent scaling** — prod can have 3 ECS tasks, dev has 2
✅ **Rollback safety** — prod issue doesn't affect dev
✅ **Lock tables separate** — dev locks don't block prod deployments

### Pre-Deployment Setup Required

Before the workflows run, you must create the **prod infrastructure state buckets**:

```bash
# Create prod S3 state bucket (one-time)
aws s3api create-bucket \
  --bucket hojadevida-terraform-state-871696174477-prod \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket hojadevida-terraform-state-871696174477-prod \
  --versioning-configuration Status=Enabled

# Create prod DynamoDB locks table (one-time)
aws dynamodb create-table \
  --table-name hojadevida-terraform-locks-871696174477-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## 2. Required GitHub Secrets & Variables

### Repository Secrets (Settings → Secrets and variables → Actions)

**MUST BE SET** before running workflows:

| Secret | Value | Where to Get |
|--------|-------|--------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::871696174477:role/github-oidc-hojadevida-izador` | From CloudFormation initial-account-setup output |
| `API_URL_DEV` | `https://{api-id}.execute-api.us-east-1.amazonaws.com` | From terraform apply output or AWS Console |
| `COGNITO_POOL_ID_DEV` | `us-east-1_xxxxxxxxx` | From terraform output `cognito_user_pool_id` |
| `COGNITO_CLIENT_ID_DEV` | `xxxxxxxxxxxxxxxxxxxxxxxxxx` | From terraform output `cognito_user_pool_client_id` |
| `API_URL_PROD` | (same format as dev) | After prod is deployed |
| `COGNITO_POOL_ID_PROD` | (same format as dev) | After prod is deployed |
| `COGNITO_CLIENT_ID_PROD` | (same format as dev) | After prod is deployed |

### Repository Variables (Settings → Secrets and variables → Variables)

**OPTIONAL** (can be hardcoded in workflows):

| Variable | Value | Purpose |
|----------|-------|---------|
| `AWS_REGION` | `us-east-1` | AWS region for all deployments |
| `TF_VERSION` | `1.14.8` | Terraform version consistency |
| `ECR_REPOSITORY` | `hojadevida-frontend` | Docker image repo name |

### How to Populate Secrets

#### Step 1: Deploy initial-account-setup (One-Time)
```bash
cd infrastructure
aws cloudformation deploy \
  --template-file initial-account-setup.yaml \
  --stack-name hojadevida-initial-setup \
  --parameter-overrides \
    GitHubOrg=estanixx \
    GitHubRepo=hojadevida-izador \
    ECRRepositoryName=hojadevida-frontend \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

Get the outputs:
```bash
aws cloudformation describe-stacks \
  --stack-name hojadevida-initial-setup \
  --query 'Stacks[0].Outputs' \
  --output table
```

Copy `Hojadevida-GitHubOIDCRoleArn` → `AWS_ROLE_ARN` secret

#### Step 2: Deploy terraform/terraform.tfvars (Dev)
```bash
cd terraform
terraform init -backend-config="bucket=hojadevida-terraform-state-871696174477-dev"
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
```

Get the outputs:
```bash
terraform output cognito_user_pool_id        # → COGNITO_POOL_ID_DEV
terraform output cognito_user_pool_client_id # → COGNITO_CLIENT_ID_DEV
terraform output api_gateway_endpoint        # → API_URL_DEV
```

#### Step 3: Set GitHub Secrets
```bash
# Using GitHub CLI
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::..."
gh secret set API_URL_DEV --body "https://..."
gh secret set COGNITO_POOL_ID_DEV --body "us-east-1_..."
gh secret set COGNITO_CLIENT_ID_DEV --body "..."
```

---

## 3. Pre-Deployment Resources Required

### Chicken-and-Egg Problem

Your workflows depend on resources that don't exist yet:

```
GitHub Actions deploy.yml needs:
  ├─ AWS OIDC Provider (created by initial-account-setup)
  ├─ GitHub OIDC Role (created by initial-account-setup)
  ├─ ECR Repository (created by initial-account-setup)
  ├─ Terraform state buckets (created manually or by script)
  └─ API Gateway, Lambda, DynamoDB, etc. (created by terraform)
```

### Recommendation: Hybrid Approach (BEST PRACTICE ✅)

**Keep initial-account-setup as CloudFormation** because:

1. **One-time setup** — Deploy once, never touch again
2. **Security boundary** — OIDC provider is an account-level resource, not per-environment
3. **Chicken-and-egg solved** — Terraform workflows can't deploy if GitHub OIDC doesn't exist
4. **Team safety** — Prevents accidental deletion of OIDC provider during infrastructure cleanup

### Step-by-Step Pre-Deployment

#### 1️⃣ Deploy Initial Account Setup (One-Time)

```bash
# This creates GitHub OIDC provider, role, and ECR repository
cd infrastructure
aws cloudformation deploy \
  --template-file initial-account-setup.yaml \
  --stack-name hojadevida-initial-account-setup \
  --parameter-overrides \
    GitHubOrg=estanixx \
    GitHubRepo=hojadevida-izador \
    ECRRepositoryName=hojadevida-frontend \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Verify it worked
aws iam list-open-id-connect-providers
aws ecr describe-repositories --query 'repositories[].repositoryUri'
```

**Outputs:**
- GitHub OIDC Role ARN → Store in GitHub secret `AWS_ROLE_ARN`
- ECR Repository URI → Use in deploy.yml

#### 2️⃣ Create Terraform State Buckets (One-Time)

```bash
# Run this script (or paste into terminal)
ACCOUNT_ID="871696174477"
REGION="us-east-1"

for ENV in dev prod; do
  BUCKET="hojadevida-terraform-state-${ACCOUNT_ID}-${ENV}"
  LOCKS_TABLE="hojadevida-terraform-locks-${ACCOUNT_ID}-${ENV}"
  
  echo "Creating state infrastructure for ${ENV}..."
  
  # Create S3 bucket
  aws s3api create-bucket \
    --bucket ${BUCKET} \
    --region ${REGION} \
    $([ "${REGION}" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=${REGION}")
  
  # Enable versioning
  aws s3api put-bucket-versioning \
    --bucket ${BUCKET} \
    --versioning-configuration Status=Enabled
  
  # Enable encryption
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
  aws s3api put-public-access-block \
    --bucket ${BUCKET} \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  
  # Create DynamoDB locks table
  aws dynamodb create-table \
    --table-name ${LOCKS_TABLE} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ${REGION}
  
  echo "✅ Created state infrastructure for ${ENV}"
done

echo "✅ All pre-deployment resources created!"
```

#### 3️⃣ Set GitHub Secrets

```bash
# Use GitHub CLI (faster)
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::871696174477:role/github-oidc-hojadevida-izador"
gh secret set API_URL_DEV --body "https://placeholder"    # Will update after first terraform apply
gh secret set COGNITO_POOL_ID_DEV --body "placeholder"     # Will update after first terraform apply
gh secret set COGNITO_CLIENT_ID_DEV --body "placeholder"   # Will update after first terraform apply
```

#### 4️⃣ Update deploy.yml with Backend Config

Replace the terraform init step with:

```yaml
- name: Terraform Init
  working-directory: terraform
  env:
    ENV: ${{ needs.determine-env.outputs.environment }}
    ACCOUNT_ID: "871696174477"
  run: |
    terraform init \
      -backend-config="bucket=hojadevida-terraform-state-${ACCOUNT_ID}-${ENV}" \
      -backend-config="key=hojadevida.tfstate" \
      -backend-config="region=us-east-1" \
      -backend-config="dynamodb_table=hojadevida-terraform-locks-${ACCOUNT_ID}-${ENV}" \
      -backend-config="encrypt=true"
```

#### 5️⃣ Deploy Dev Infrastructure First

```bash
# Manual first deployment before using workflows
cd terraform
terraform init \
  -backend-config="bucket=hojadevida-terraform-state-871696174477-dev" \
  -backend-config="dynamodb_table=hojadevida-terraform-locks-871696174477-dev" \
  -backend-config="key=hojadevida.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"

terraform apply -var-file=terraform.tfvars -auto-approve
```

Get outputs and update GitHub secrets:
```bash
terraform output -json | jq '.cognito_user_pool_id.value' # → COGNITO_POOL_ID_DEV
terraform output -json | jq '.cognito_user_pool_client_id.value' # → COGNITO_CLIENT_ID_DEV
terraform output -json | jq '.api_gateway_endpoint.value' # → API_URL_DEV
```

#### 6️⃣ Deploy Prod Infrastructure (Optional, When Ready)

```bash
cd terraform
terraform init \
  -backend-config="bucket=hojadevida-terraform-state-871696174477-prod" \
  -backend-config="dynamodb_table=hojadevida-terraform-locks-871696174477-prod" \
  -backend-config="key=hojadevida.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"

terraform apply -var-file=terraform.prod.tfvars -auto-approve
```

Update prod secrets in GitHub.

---

## 4. GitHub Branch Protection Rules (Replace protect-prod.yml)

### Why Replace protect-prod.yml?

- ✅ GitHub branch rules are enforced at the platform level (can't bypass)
- ❌ Workflows can be modified in PRs and skipped
- ✅ More reliable and maintainable
- ❌ Don't need a separate workflow

### Setup Branch Protection (GitHub Web UI)

1. Go to: **Settings → Branches → Add rule**

2. **For `prod` branch:**
   - Pattern: `prod`
   - ✅ **Require pull request reviews before merging** (1 approval)
   - ✅ **Require status checks to pass**
     - Select: `terraform-plan` (from plan.yml)
     - Select: `security-checks` (from plan.yml)
   - ✅ **Require branches to be up to date before merging**
   - ✅ **Restrict who can push to matching branches**
     - Allow: `@estanixx/admins` (or your team)
   - ❌ **Allow force pushes** (uncheck)
   - ❌ **Allow deletions** (uncheck)

3. **For `main` branch (optional):**
   - Pattern: `main`
   - ✅ **Require pull request reviews** (1 approval)
   - ✅ **Require status checks to pass**
     - Select: `terraform-plan`
   - ❌ **Require branches to be up to date** (depends on your workflow)

4. **Delete `protect-prod.yml`**
   ```bash
   rm .github/workflows/protect-prod.yml
   git add -A && git commit -m "Remove protect-prod.yml, use GitHub branch rules instead"
   ```

### How It Works

- User tries to push to `prod` → **Rejected by GitHub** (can't bypass)
- User creates PR to `prod` → plan.yml runs automatically
- PR comment shows terraform plan
- Requires 1 approval + all checks pass
- Only after merge is prod deployed

---

## 5. Testing Workflow Checklist

Before Phase 1.10, test the following:

### Pre-Test Setup

- [ ] Deploy initial-account-setup CloudFormation stack
- [ ] Create Terraform state buckets (dev & prod)
- [ ] Set `AWS_ROLE_ARN` GitHub secret
- [ ] Update deploy.yml with `-backend-config` for init
- [ ] Manually deploy dev infrastructure (terraform apply)
- [ ] Update GitHub secrets with API_URL_DEV, COGNITO_* values
- [ ] Delete protect-prod.yml
- [ ] Add GitHub branch protection rules for `prod`
- [ ] Push changes to main and create prod branch

### Test 1: Dev Auto-Deployment ✅

```bash
# On main branch
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger dev deployment"
git push origin main
```

**Expected:**
- GitHub Actions runs deploy.yml
- determine-env → dev
- terraform-deploy → runs plan & apply (no-op since code didn't change)
- backend-deploy → updates Lambda (no-op)
- frontend-deploy → builds & pushes Docker image
- verify-deployment → shows ECS status
- ✅ Completes in ~5-10 minutes

**Verify:**
```bash
aws lambda get-function --function-name hojadevida-listCvs-dev
aws ecs describe-services --cluster hojadevida-cluster --services hojadevida-frontend-service
```

### Test 2: PR Plan Comment ✅

```bash
git checkout -b test/pr-plan
echo "# Feature branch" >> README.md
git add README.md
git commit -m "test: create PR for plan comment"
git push origin test/pr-plan
```

Open PR to `main` in GitHub UI

**Expected:**
- plan.yml runs automatically
- Comment appears on PR showing terraform plan
- No changes (code didn't modify infrastructure)
- ✅ Plan shows "no changes"

### Test 3: Prod Branch Protection ✅

Try to push directly to prod:
```bash
git checkout prod
echo "# Direct push test" >> README.md
git add README.md
git commit -m "test: direct push to prod"
git push origin main:prod
```

**Expected:**
- ❌ Push rejected by GitHub branch protection rule
- Message: "Require status checks to pass before merging"
- Only PR workflow allowed

### Test 4: Prod PR Workflow ✅

```bash
git checkout main
git pull origin main
git checkout -b feature/prod-test
echo "# Prod feature" >> README.md
git add README.md
git commit -m "feat: prod test"
git push origin feature/prod-test
```

Create PR to `main`, get approval, merge

Then:
```bash
git checkout -b prod-deployment origin/main
git push origin prod-deployment:prod
```

**Or use GitHub UI:** Create PR from `main` → `prod`

**Expected:**
- plan.yml runs with terraform.prod.tfvars
- Comment shows prod-specific plan (different counts/settings)
- Requires approval
- After merge, deploy.yml runs with prod config
- ✅ Deploys prod infrastructure

---

## Summary Table

| Item | Action | When |
|------|--------|------|
| initial-account-setup.yaml | Deploy once via CloudFormation | Before any GitHub workflow runs |
| Terraform state buckets | Create manually (dev & prod) | Before first terraform apply |
| GitHub secrets | Set in GitHub UI or CLI | Before workflows run |
| protect-prod.yml | Delete | Replace with GitHub branch rules |
| deploy.yml | Update terraform init step | Before first push to main |
| GitHub branch rules | Add prod and main rules | Before testing workflows |
| Test 1: Dev deploy | Push to main | After all setup complete |
| Test 2: PR plan | Create PR to main | After Test 1 passes |
| Test 3: Prod protection | Try direct push | After Test 2 passes |
| Test 4: Prod PR | Create PR main→prod | After Test 3 passes |

---

## Next: You Need To Do

1. ✏️ **Review this document** — any questions?
2. 🛠️ **Deploy initial-account-setup** (one-time)
3. 🪣 **Create Terraform state buckets** (one-time)
4. 🔐 **Set GitHub secrets** (one-time)
5. 📝 **Update deploy.yml** with `-backend-config`
6. 🗑️ **Delete protect-prod.yml**, add GitHub branch rules
7. 🧪 **Run test checklist** before Phase 1.10

Should I update the files and create the pre-deployment guide, or do you want to handle this manually?
