# Plan Review Summary & Strategic Decisions

## Your Questions → My Answers

### 1. Frontend Infrastructure Already in CloudFormation
✅ **Observation Correct**
- `infrastructure/frontend-setup.yaml` has ECS Fargate, ALB, VPC, security groups
- **Action**: Include this in Phase 1 Terraform refactor (not just backend)
- **Impact**: Slightly longer Phase 1 (6-8 days instead of 5-7), but **much cleaner** result

---

### 2. Lambda/API Gateway/S3/DynamoDB: Use Serverless Framework or Terraform?

#### Decision: **Terraform Only** ✅

| Aspect | Terraform Only | Serverless + Terraform | SAM + Terraform |
|--------|---|---|---|
| State Files | 1 | 2 (serverless-state.json + tfstate) | 2 (SAM CF + tfstate) |
| Cross-References | ✅ Direct | ❌ Indirect (env vars) | ❌ Indirect |
| SQS Decoupling | ✅ Trivial | ⚠️ Complex | ⚠️ Complex |
| Deployment | ✅ Single `terraform apply` | ❌ `serverless deploy` + `terraform apply` | ❌ `sam deploy` + `terraform apply` |
| Local Dev | ❌ Harder | ✅ `serverless offline` | ✅ `sam local` |
| Complexity | 🟠 Moderate | 🔴 High | 🔴 High |
| Team Experience | 🟠 Terraform learning | ✅ Serverless familiar | 🔴 SAM unfamiliar |

**Why Terraform Only is Right for You**:

1. **Frontend already in CloudFormation** → keeping Serverless Framework adds fragmentation
2. **Future SQS decoupling** becomes **trivial** in Terraform:
   ```hcl
   resource "aws_sqs_queue" "cv_jobs" { }
   resource "aws_lambda_event_source_mapping" "process_queue" {
     event_source_arn = aws_sqs_queue.cv_jobs.arn  # ← Direct reference
   }
   ```
   vs. with Serverless + Terraform: must export/import across tools

3. **Single state file** = no synchronization issues, clearer deployment

4. **Terraform's Lambda support is excellent** (not lacking features)

---

### 3. Phase 2 Task 2.5: PDF Generation Enhancement ✅
**Recommendation**: YES, use `pdfkit`

Why `pdfkit`?
- Pure Node.js (no external dependencies)
- Works in Lambda environment
- Produces real PDF with fonts, spacing, formatting
- Lightweight (~300KB)
- Simple to implement

**When**: Early in Phase 2 (low risk, immediate UX improvement)

**Code Pattern**:
```javascript
// backend/lib/pdf-generator.js
const PDFDocument = require('pdfkit');

exports.generatePdf = (resumeData) => {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    const chunks = [];
    
    doc.on('data', chunk => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    
    // Add sections with formatting
    doc.fontSize(20).font('Helvetica-Bold').text(resumeData.Header);
    doc.moveTo(50, doc.y + 10).lineTo(545, doc.y + 10).stroke();  // Horizontal line
    doc.fontSize(11).font('Helvetica').text(resumeData.Summary);
    // ... more sections
    
    doc.end();
  });
};
```

---

### 4. Future SQS Decoupling: Terraform vs SAM?

#### Decision: **Terraform Only** ✅

**Why**:
- Cleanest architecture for event-driven decoupling
- Direct queue-to-Lambda event source mapping
- No tool fragmentation

**Implementation Pattern**:
```
API → acceptCvJob Lambda (writes to SQS, returns jobId)
       ↓
     SQS Queue
       ↓
processCvJob Lambda (event source mapping)
       ↓
Bedrock + S3 + DynamoDB
       ↓
SNS (optional: notify user when complete)
```

**Terraform handles all of this cleanly**:
```hcl
resource "aws_lambda_event_source_mapping" "sqs_to_process" {
  event_source_arn = aws_sqs_queue.cv_jobs.arn
  function_name    = aws_lambda_function.process_cv_job.arn
  batch_size       = 1
}
```

---

## 10 Critical Architectural Recommendations

### 🔴 CRITICAL (Do First)

#### 1. **Fix CORS Configuration**
**Current**: Allows all origins (`*`)
**Fix**: Restrict to frontend domain
```hcl
cors_configuration {
  allow_origins = ["https://your-domain.com"]
  allow_methods = ["GET", "POST", "OPTIONS"]
  allow_headers = ["Content-Type", "Authorization"]
}
```
**Impact**: Security vulnerability in production

#### 2. **Improve Bedrock Prompt**
**Current**: May hallucinate untruthful information
**Fix**: Add explicit constraints in prompt
```
CRITICAL CONSTRAINTS:
1. ONLY include information explicitly provided in the input
2. NEVER invent skills, achievements, or experience
3. NEVER hallucinate dates, company names, or metrics
4. If a field is empty, omit that section or write "Not Provided"
5. Emphasize achievements that align with desired role
```
**Impact**: Better CV accuracy, user trust

#### 3. **Add Input Validation**
**Current**: Minimal validation in handler.js
**Fix**: Schema validation + size checks
```javascript
- Check required fields (name, email, desired role)
- Require at least 1 experience OR 1 skill
- Reject if payload > 50KB (prevent token waste)
```
**Impact**: Prevent invalid requests, clearer error messages

---

### 🟡 IMPORTANT (Do in Phase 1)

#### 4. **Enable S3 Encryption + Lifecycle Policy**
**Fix**: AES-256 encryption + 90-day archive to Glacier
```hcl
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

lifecycle_configuration {
  rule {
    noncurrent_version_expiration { noncurrent_days = 90 }
    transition { days = 365; storage_class = "GLACIER" }
  }
}
```
**Impact**: Security + cost savings

#### 5. **Enable DynamoDB Point-in-Time Recovery (PITR)**
**Fix**: One-line addition
```hcl
point_in_time_recovery_specification {
  enabled = true
}
```
**Impact**: Can recover to any point in last 35 days

#### 6. **Add DynamoDB Global Secondary Index (GSI)**
**Fix**: Query by userId + createdAt (not just userId)
```hcl
global_secondary_index {
  name      = "userIdCreatedAtGSI"
  hash_key  = "userId"
  range_key = "createdAt"
}
```
**Impact**: Enable date-based queries, sorting, filtering

---

### 🟠 MEDIUM PRIORITY (Do in Phase 1-2)

#### 7. **Lambda Reserved Concurrency**
**Fix**: Cap max concurrent executions (prevent cost blowout)
```hcl
reserved_concurrent_executions = 10  # Prod
```
**Impact**: Cost predictability

#### 8. **CloudWatch Alarms & Monitoring**
**Fix**: Alert on Lambda errors, Bedrock throttling
```hcl
cloudwatch_metric_alarm "lambda_errors" {
  alarm_name          = "hojadevida-lambda-errors"
  threshold           = 5  # >5 errors in 5 minutes
  comparison_operator = "GreaterThanThreshold"
}
```
**Impact**: Incident response, cost control

#### 9. **Secrets Manager for Sensitive Config**
**Fix**: Move credentials from env vars to Secrets Manager
```hcl
# Pre-production planning
resource "aws_secretsmanager_secret" "bedrock_config" {
  name = "hojadevida/bedrock-${var.stage}"
}
```
**Impact**: Production security readiness

#### 10. **Frontend Environment Variables**
**Fix**: Clear defaults, build-time injection
```dockerfile
ARG NEXT_PUBLIC_API_URL=http://localhost:3000
ARG NEXT_PUBLIC_COGNITO_USER_POOL_ID=local-dev

ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
```
**Impact**: Clean separation of config and code

---

## Updated Phase 1: Complete Infrastructure Refactor

### Scope (Expanded)
✅ All backend resources (Lambda, API Gateway, DynamoDB, S3)
✅ All frontend resources (ECS, ALB, VPC, security groups)
✅ Auth (Cognito, OIDC for GitHub)
✅ State management (S3 backend + DynamoDB locks)
✅ Monitoring (CloudWatch logs + alarms)
✅ Security (encryption, CORS, validation)

### Duration
**6-8 days** (vs original 5-7, due to including frontend infrastructure)

### Terraform Structure
```
terraform/
├── main.tf              # Provider config
├── variables.tf         # Input variables
├── terraform.tfvars     # Default values
├── outputs.tf           # Exports (API URL, Cognito IDs)
│
├── iam.tf              # Roles, permission boundaries
├── oidc.tf             # GitHub OIDC setup
├── cognito.tf          # User Pool, Client, Domain
├── dynamodb.tf         # CVs table + GSI + PITR
├── s3.tf               # PDF storage + encryption + lifecycle
├── lambda.tf           # listCvs, generateCv functions
├── apigateway.tf       # HTTP API + JWT authorizer + CORS fix
├── vpc.tf              # VPC, subnets, security groups
├── ecs.tf              # ECS cluster, task definition
├── alb.tf              # Load balancer, target groups
├── cloudwatch.tf       # Log groups + alarms
└── state.tf            # S3 backend + locks
```

### Deliverable
✅ Single `terraform apply` deploys entire application
✅ All recommendations integrated
✅ Security hardened (CORS, encryption, validation)
✅ Monitoring in place
✅ Ready for Phases 2-5

---

## Decision Summary Table

| Decision | Choice | Why | Future-Proof? |
|----------|--------|-----|---|
| IaC Tool | Terraform Only | Single state, clean refs, SQS-ready | ✅ YES |
| Phase 1 Scope | All infra (backend + frontend) | No fragmentation | ✅ YES |
| PDF Generation | pdfkit library | Pure Node.js, Lambda-safe | ✅ YES |
| SQS Decoupling | Terraform event mappings | Trivial to implement later | ✅ YES |
| CORS | Restrict to domain | Security, no breaking changes needed | ✅ YES |
| Bedrock Prompt | Enhanced with constraints | Better accuracy | ✅ YES |
| S3 Encryption | AES-256 + lifecycle | Default best practice | ✅ YES |

---

## Next Steps

### Immediate (Choose One)
1. **Approve approach** → Start Phase 1 immediately
2. **Refine specifics** → Discuss any adjustments
3. **Review details** → Read ARCHITECTURE_REVIEW.md for full explanations

### Phase 1 Preparation (Before Coding)
- [ ] Set up S3 bucket for Terraform state (manually or via script)
- [ ] Create DynamoDB table for locks (manually or via script)
- [ ] Configure AWS credentials for GitHub Actions OIDC role
- [ ] Document Terraform variable overrides for dev/staging/prod

### Phase 1 Execution
- [ ] Create `/terraform` directory structure
- [ ] Migrate CloudFormation resources to `.tf` files
- [ ] Test `terraform plan` shows all resources
- [ ] Deploy to dev, validate parity with old infra
- [ ] Update GitHub Actions pipeline
- [ ] Decommission old CloudFormation stacks

---

## Risk Mitigation

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| Terraform state corruption | LOW | Enable S3 versioning + backups |
| Resource drift (manual changes) | MEDIUM | Run `terraform plan` weekly |
| Cross-tool state issues | HIGH | By using Terraform-only, eliminated |
| CORS breaking frontend | LOW | Test in dev before prod |
| Bedrock hallucination | MEDIUM | Enhanced prompt + user feedback loop |

---

## Success Criteria for Phase 1

- ✅ `terraform apply` deploys all resources
- ✅ Lambda functions invocable via API Gateway
- ✅ Cognito sign-up/sign-in works
- ✅ Frontend ECS tasks serving traffic
- ✅ DynamoDB queries return correct user CVs
- ✅ S3 presigned URLs work
- ✅ CloudWatch logs capturing errors
- ✅ Zero manual resource creation needed
- ✅ GitHub Actions pipeline automated

---

**I'm ready to begin Phase 1 whenever you give the green light.**

Questions or adjustments to this plan?
