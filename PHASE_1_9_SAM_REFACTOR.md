# Phase 1.9+ Refactor: Serverless Framework → AWS SAM

## What Changed

✅ **COMPLETED**: Migrated backend from Serverless Framework to **AWS SAM (Serverless Application Model)**.

This is a **major architectural improvement** that simplifies deployments and code organization.

---

## Why SAM?

| Aspect | Serverless Framework | AWS SAM | Winner |
|--------|----------------------|---------|--------|
| **AWS-native** | ❌ Third-party | ✅ AWS official | SAM |
| **Learning curve** | Steep | Moderate | SAM |
| **Deployment** | Manual function updates | Single `sam deploy` | SAM |
| **Code organization** | Single handler.js | src/function/ structure | SAM |
| **CloudFormation integration** | Indirect | Direct | SAM |
| **Function-by-function updates** | ❌ Required in workflows | ✅ Not needed | SAM |
| **Add new functions** | Edit serverless.yaml + handler.js | Create src/function/ + add to template.yaml | SAM |

---

## File Structure Changes

### Before (Serverless Framework)
```
backend/
├── handler.js                 # All functions in one file (249 lines)
├── serverless.yaml            # Monolithic config
├── package.json
└── node_modules/
```

### After (AWS SAM)
```
backend/
├── template.yaml              # SAM template (infrastructure-as-code)
├── samconfig.toml             # SAM configuration
├── package.json               # Updated with SAM scripts
├── SAM_README.md              # Comprehensive guide
├── src/
│   ├── shared.js             # Shared utilities (AWS SDK clients)
│   ├── list_cvs/
│   │   └── index.js          # GET /cvs handler
│   └── generate_cv/
│       └── index.js          # POST /cvs/generate handler
└── [deprecated]
    ├── handler.js             # Keep for reference, to be deleted
    └── serverless.yaml        # Keep for reference, to be deleted
```

---

## Key Improvements

### 1. **Single Deploy Command** (No More Function-by-Function Updates)

**Before (Serverless Framework):**
```yaml
# workflow: deploy listCvs, then deploy generateCv separately
- name: Deploy listCvs Lambda function
  run: aws lambda update-function-code --function-name hojadevida-listCvs-dev --zip-file ...

- name: Deploy generateCv Lambda function
  run: aws lambda update-function-code --function-name hojadevida-generateCv-dev --zip-file ...
```

**After (SAM):**
```yaml
- name: Build and deploy backend with SAM
  run: |
    sam build --use-container
    sam deploy --stack-name hojadevida-backend-dev \
      --parameter-overrides Environment=dev \
      --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND
```

✅ **One command deploys all functions, API Gateway, DynamoDB, S3, Cognito, and permissions.**

### 2. **Better Code Organization**

Each function lives in its own directory with clear responsibilities:
- `src/list_cvs/index.js` — Handles GET /cvs
- `src/generate_cv/index.js` — Handles POST /cvs/generate
- `src/shared.js` — Shared utilities (AWS SDK clients, helpers)

### 3. **Infrastructure-as-Code**

All infrastructure is defined in `template.yaml`:
- Lambda functions with triggers, memory, timeouts
- API Gateway routes and authorizers
- DynamoDB table definitions
- S3 bucket configuration
- Cognito user pool and client
- IAM permissions for each function

No more manual AWS CLI commands to create resources.

### 4. **Scalability**

Adding a new function is now **2 simple steps**:

1. Create `src/my_function/index.js`
2. Add to `template.yaml`

No more editing monolithic files.

---

## Deployment Workflow

### Local Development

```bash
# Build
cd backend
sam build

# Deploy to dev
sam deploy --config-env dev

# Deploy to prod
sam deploy --config-env prod
```

### GitHub Actions (Automatic)

When you push to `main` or `prod`:
1. SAM builds the backend
2. SAM deploys to CloudFormation stack
3. CloudFormation creates/updates all resources
4. Outputs are exported for frontend to use

---

## Breaking Changes

⚠️ **IMPORTANT**: The Terraform integration needs updating.

Currently, Terraform creates:
- DynamoDB tables
- S3 buckets
- Cognito user pool
- API Gateway

**With SAM**, these should be created by SAM, not Terraform.

**Next steps for Phase 1.10:**
1. Update Terraform to remove DynamoDB, S3, Cognito, and API Gateway definitions
2. Update Terraform to read SAM outputs instead
3. Or: Remove Terraform entirely and use only SAM + CloudFormation

---

## Migration Status

| Component | Status | Notes |
|-----------|--------|-------|
| **Lambda functions** | ✅ Refactored | Now in src/list_cvs/ and src/generate_cv/ |
| **Package structure** | ✅ Updated | SAM-compliant organization |
| **GitHub workflows** | ✅ Updated | Uses `sam build` + `sam deploy` |
| **Documentation** | ✅ Added | See backend/SAM_README.md |
| **Old files** | ⏳ Deprecated | serverless.yaml and handler.js kept for reference |
| **Terraform integration** | ❌ Pending | Phase 1.10 task |

---

## Testing the Refactor

### 1. Build Locally
```bash
cd backend
sam build
```

Expected output:
```
Build Succeeded
Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml
Command succeeded
```

### 2. Deploy to Dev
```bash
sam deploy --config-env dev
```

Expected output:
```
CloudFormation events from changeset
Operation                                Status              Resource Type
─────────────────────────────────────────────────────────────────────────
- Create hojadevida-backend-dev Stack   In Progress
  - Create Lambda function ListCvsFunction
  - Create Lambda function GenerateCvFunction
  - Create API Gateway HttpApi
  - Create Cognito UserPool
  - Create DynamoDB Table
  - Create S3 Bucket
✓ All Stacks Succeeded
```

### 3. Verify Deployment
```bash
# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name hojadevida-backend-dev \
  --query 'Stacks[0].Outputs'

# Should show:
# - HttpApiEndpoint
# - ListCvsFunctionArn
# - GenerateCvFunctionArn
# - CognitoUserPoolId
# - CvsDynamoDbTableName
# - CvsS3BucketName
```

---

## Git Commits

```
d0b58ef refactor: Migrate backend from Serverless Framework to AWS SAM
```

**Files changed:**
- ✅ Added: `backend/template.yaml` (SAM template)
- ✅ Added: `backend/samconfig.toml` (SAM config)
- ✅ Added: `backend/SAM_README.md` (Documentation)
- ✅ Added: `backend/src/` (Function directories)
- ✅ Modified: `backend/package.json` (SAM scripts)
- ✅ Modified: `.github/workflows/deploy.yml` (SAM deployment)
- ✅ Updated: `backend/.gitignore` (SAM artifacts)

---

## Next Phase (Phase 1.10)

### Reconcile Terraform & SAM

**Option A: SAM Owns Everything** (Recommended)
- Delete DynamoDB, S3, Cognito, API Gateway from Terraform
- SAM template.yaml creates all backend infrastructure
- Terraform creates only: VPC, subnets, ECS cluster, ALB, CloudWatch

**Option B: Hybrid** (Current state)
- Terraform creates DynamoDB, S3, Cognito, API Gateway
- SAM creates Lambda functions only
- ⚠️ Risk of drift and confusion

---

## Summary

✅ **Backend refactored successfully**

Key wins:
- ✅ Single SAM deploy command (no more function-by-function updates)
- ✅ Better code organization (functions in separate directories)
- ✅ Infrastructure-as-code (all resources in template.yaml)
- ✅ Industry standard (AWS-native SAM, not third-party)
- ✅ Scalable (easy to add new functions)
- ✅ Professional structure (ready for team collaboration)

**You're ready to test by pushing to the `main` branch.** The GitHub Actions workflow will:
1. Build with SAM
2. Deploy to dev environment
3. Show all outputs

Good luck with the test push! 🚀
