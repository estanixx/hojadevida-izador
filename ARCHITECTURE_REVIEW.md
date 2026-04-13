# Architecture Review & Implementation Strategy Refinement

## Your Key Observations & Questions

### 1. Frontend Infrastructure Already in CloudFormation
**Observation**: `infrastructure/frontend-setup.yaml` already handles frontend (ECS Fargate, ALB, security groups, CloudWatch logs)

**Implication**: Phase 1 should include this infrastructure in the Terraform refactor, not just backend resources.

**Recommendation**: ✅ **Expand Phase 1 scope to include ALL infrastructure**
- `/infrastructure/initial-account-setup.yaml` → `terraform/iam.tf`, `terraform/oidc.tf`
- `/infrastructure/frontend-setup.yaml` → `terraform/ecs.tf`, `terraform/alb.tf`, `terraform/vpc.tf` (networking)
- `/infrastructure/network-setup.yaml` → `terraform/vpc.tf`
- `/backend/serverless.yaml` → `terraform/lambda.tf`, `terraform/apigateway.tf`, `terraform/cognito.tf`

This is more work than originally estimated, but **MUCH cleaner** than maintaining both CloudFormation and Serverless YAML.

---

### 2. Lambda + API Gateway + S3 + DynamoDB: CloudFormation vs Serverless Framework?

**Your Question**: "Wouldn't it be better to use Serverless Framework instead of Terraform for Lambda/APIGW?"

This is the **critical architectural decision**. Let me break down the tradeoffs:

#### Option A: Terraform Only (My Original Recommendation)
```
Terraform manages EVERYTHING:
├── Lambda functions (aws_lambda_function)
├── API Gateway (aws_apigatewayv2_*)
├── S3 (aws_s3_bucket)
├── DynamoDB (aws_dynamodb_table)
├── Cognito (aws_cognito_*)
├── IAM roles (aws_iam_role)
└── ECS/ALB/Frontend (aws_ecs_*)
```

**Pros**:
- ✅ Single source of truth (no Serverless YAML + Terraform duplication)
- ✅ Consistent state management (one terraform.tfstate)
- ✅ Easy to reference resources across layers (e.g., Lambda role can reference DynamoDB ARN directly)
- ✅ Full infrastructure visibility in Terraform plan/apply
- ✅ Version control friendly (one git repo, one state)
- ✅ Better for incremental changes

**Cons**:
- ❌ Terraform is verbose for serverless patterns (more boilerplate)
- ❌ Lose Serverless Framework's convenience features (function packaging, offline testing)
- ❌ More infrastructure code to maintain
- ❌ Lambda versioning/aliases need manual management

#### Option B: Serverless Framework for Backend + Terraform for Frontend/Networking
```
Serverless Framework manages:
├── Lambda functions
├── API Gateway
├── DynamoDB
└── S3

Terraform manages:
├── Cognito (if not in Serverless)
├── ECS/ALB/Frontend
├── VPC/Networking
├── IAM permission boundaries
└── State backend (S3 + DynamoDB locks)
```

**Pros**:
- ✅ Serverless handles function packaging automatically
- ✅ Familiar Serverless workflow for backend developers
- ✅ Faster local testing with `serverless offline`
- ✅ Function-level control over versioning/aliases
- ✅ Keeps backend isolated from frontend infra

**Cons**:
- ❌ **TWO state files** (serverless-state.json + terraform.tfstate) = hard to reason about
- ❌ Hard cross-references (Lambda needs Cognito ID, but they're in different state files)
- ❌ Two deployment pipelines (serverless deploy vs terraform apply)
- ❌ State synchronization issues if either fails mid-deploy
- ❌ More complex GitHub Actions workflow
- ❌ When refactoring, hard to know what's deployed where

#### Option C: SAM (Serverless Application Model) + Terraform
```
SAM manages (CloudFormation under the hood):
├── Lambda functions
├── API Gateway
└── Some AWS services (DynamoDB, S3 via CloudFormation)

Terraform manages:
├── Cognito
├── ECS/ALB/Frontend
├── VPC/Networking
└── Terraform state
```

**Pros**:
- ✅ SAM is AWS-official and purpose-built for Lambda
- ✅ Better integration with AWS services
- ✅ Can mix SAM + CloudFormation + Terraform

**Cons**:
- ❌ Still fragmented (SAM generates CloudFormation, adds another layer)
- ❌ Same state management issues as Option B
- ❌ Learning curve for SAM if team knows Serverless
- ❌ Less popular in community compared to Serverless Framework

---

### 🎯 **My Strong Recommendation: Option A (Terraform Only)**

**Here's why, specifically for your use case**:

1. **You already have CloudFormation** in `/backend/serverless.yaml` — this is essentially CloudFormation-by-proxy. The Serverless Framework is just generating CloudFormation.

2. **Frontend is already in Terraform-ish infra** (CloudFormation) — keeping both Serverless + Terraform means two state management systems for ONE application. That's **architectural debt waiting to happen**.

3. **Your future SQS decoupling** (you asked about this below) will require cross-service references:
   ```
   Lambda A writes to SQS → Lambda B reads from SQS → DynamoDB
   ```
   This is MUCH easier in pure Terraform where you can do:
   ```hcl
   # terraform/queues.tf
   resource "aws_sqs_queue" "cv_generation" { ... }
   
   # terraform/lambda.tf
   resource "aws_lambda_event_source_mapping" "process_queue" {
     event_source_arn = aws_sqs_queue.cv_generation.arn  # ← Direct reference
     function_name    = aws_lambda_function.process_cv.arn
   }
   ```

4. **Single deployment pipeline** via GitHub Actions:
   ```bash
   terraform init
   terraform plan
   terraform apply
   # ✅ DONE. All resources deployed atomically.
   ```
   
   vs. with Serverless + Terraform:
   ```bash
   serverless deploy --stage prod
   terraform apply
   # ⚠️ If second fails, recovery is messy
   ```

5. **Terraform's Lambda support is strong** — not lacking features. You can:
   - Package functions as ZIP (inline, from S3, from Lambda layers)
   - Manage environment variables, VPC config, reserved concurrency
   - Use `aws_lambda_function` + `aws_lambda_permission` for fine control
   - No overhead vs Serverless Framework

---

### ⚠️ **BUT — One Exception to Consider**

If your team **heavily uses Serverless Framework for local development** (`serverless offline`), you could keep a **hybrid approach**:

**Serverless for local development ONLY**:
- Dev runs `serverless offline` to test Lambda + API Gateway locally
- Prod uses Terraform for actual deployment (Serverless config not used)
- This requires discipline: keep `serverless.yaml` in sync with Terraform manually

**Verdict**: NOT recommended unless local dev speed is critical. Better to use `sam local start-api` or terraform-based local testing if needed.

---

## Revised Phase 1: Terraform-Only Backend + Infrastructure

### Terraform Directory Structure
```
terraform/
├── main.tf                    # Provider, Terraform version constraints
├── variables.tf               # Input variables (region, stage, etc.)
├── terraform.tfvars           # Default values (dev, staging, prod)
├── terraform.tfvars.prod      # Production-specific overrides
├── outputs.tf                 # Export API endpoints, Cognito IDs, etc.
│
├── iam.tf                     # IAM roles, policies, permission boundaries
├── oidc.tf                    # GitHub OIDC provider setup
├── cognito.tf                 # Cognito User Pool, Client, Domain
├── dynamodb.tf                # DynamoDB table for CVs
├── s3.tf                      # S3 bucket for PDFs
├── lambda.tf                  # Lambda functions (listCvs, generateCv)
├── apigateway.tf              # HTTP API Gateway, JWT authorizer, routes
├── vpc.tf                     # VPC, subnets, security groups (from network-setup.yaml)
├── ecs.tf                     # ECS cluster, task definition (from frontend-setup.yaml)
├── alb.tf                     # ALB, target groups, listeners (from frontend-setup.yaml)
├── cloudwatch.tf              # CloudWatch log groups
├── state.tf                   # S3 backend for Terraform state
│
└── modules/                   # (Optional) Reusable modules
    ├── lambda/               # Reusable Lambda function module
    └── ecs_service/          # Reusable ECS service module
```

### Phase 1 Tasks (Refined)

#### Task 1.1: Set Up Terraform Backend (S3 + DynamoDB Locks)
- Create S3 bucket: `hojadevida-terraform-state-{stage}`
- Create DynamoDB table: `terraform-locks`
- Write `state.tf` to configure backend
- Initialize Terraform: `terraform init -backend-config=...`

#### Task 1.2: Migrate Cognito & Auth Resources
- `cognito.tf`: User Pool, Client, Domain
- `oidc.tf`: GitHub OIDC provider from `initial-account-setup.yaml`
- `iam.tf`: IAM roles and permission boundaries
- Validate with: `terraform plan` — should match current Cognito setup

#### Task 1.3: Migrate Lambda + API Gateway + DynamoDB + S3
- `lambda.tf`: 
  - Package `/backend/handler.js` as ZIP
  - Create `aws_lambda_function` for `listCvs` and `generateCv`
  - Manage environment variables (CVS_TABLE, CVS_BUCKET)
- `apigateway.tf`:
  - Create HTTP API with JWT authorizer
  - Routes: GET /cvs, POST /cvs/generate
  - CORS configuration (restrict to frontend domain)
- `dynamodb.tf`: Table with userId + cvId keys
- `s3.tf`: Bucket with private ACL

#### Task 1.4: Migrate Frontend Infrastructure
- `vpc.tf`: VPC, subnets, security groups (from `network-setup.yaml`)
- `ecs.tf`: ECS cluster, task definition
- `alb.tf`: Application Load Balancer, target groups
- `cloudwatch.tf`: CloudWatch log groups for ECS

#### Task 1.5: Export Outputs for Frontend Configuration
- HTTP API URL → frontend reads via env var
- Cognito User Pool ID → frontend reads via env var
- Cognito Client ID → frontend reads via env var
- ALB DNS name → Route 53 CNAME (or direct)

#### Task 1.6: GitHub Actions CI/CD Pipeline
- Update `.github/workflows/deploy.yml`:
  - Run `terraform init -backend-config=...`
  - Run `terraform plan -out=tfplan`
  - Run `terraform apply tfplan`
  - Retrieve outputs: `terraform output http_api_url` → pass to frontend build

#### Task 1.7: Validation & Parity Testing
- Deploy to dev stage with Terraform
- Verify Lambda invocation: `aws lambda invoke --function-name listCvs /tmp/response.json`
- Verify Cognito sign-up/sign-in flow
- Verify frontend can reach backend API
- Compare CloudFormation stacks before deletion (ensure no missed resources)

#### Task 1.8: Cleanup & Documentation
- Decommission old CloudFormation stacks (after validation)
- Remove `/backend/serverless.yaml`
- Remove `/infrastructure/*.yaml` (now in Terraform)
- Update README with Terraform deployment instructions
- Document variable overrides for different stages

---

## Phase 2: PDF Generation Enhancement (Task 2.5)

### Observation: Current PDF Generation
Currently, `renderPseudoPdfContent()` in `handler.js` returns **text**, not PDF:
```javascript
return Buffer.from(baseSections.join('\n'), 'utf-8');  // ← Text, not PDF
```

This is stored in S3 as `application/pdf` mime type, but it's actually a **text file**, not a real PDF.

### Recommended Solution: Use `pdfkit`

**Why `pdfkit`?**
- ✅ Pure Node.js (no external binary dependencies)
- ✅ Generates proper PDF (not text)
- ✅ Easy to style: fonts, colors, spacing, page breaks
- ✅ Lightweight (~300KB)
- ✅ MIT licensed
- ✅ Works in Lambda environment

**Alternative**: `html-pdf` or `puppeteer` — but these need headless Chrome, which is **too heavy for Lambda**. `pdfkit` is the right choice.

### Implementation Plan

#### Phase 2 Task 2.5a: Add `pdfkit` Dependency
```bash
cd backend
npm install pdfkit
```

#### Phase 2 Task 2.5b: Create PDF Rendering Function
```javascript
// backend/pdf-generator.js
const PDFDocument = require('pdfkit');

const generatePdf = (resumeData) => {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    const chunks = [];

    doc.on('data', chunk => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    // Header
    doc.fontSize(24).font('Helvetica-Bold')
       .text(resumeData.Header || 'Resume', { align: 'center' });
    doc.moveTo(50, doc.y + 10).lineTo(545, doc.y + 10).stroke();

    // Summary
    doc.fontSize(12).font('Helvetica-Bold')
       .text('SUMMARY', { underline: false });
    doc.fontSize(11).font('Helvetica')
       .text(resumeData.Summary || '', { align: 'left' });

    // Experience, Skills, Education, Languages, Certifications
    // (Similar pattern for each section)

    doc.end();
  });
};

module.exports = { generatePdf };
```

#### Phase 2 Task 2.5c: Update Handler to Use PDF Generation
```javascript
// backend/handler.js
const { generatePdf } = require('./pdf-generator');

const pdfBytes = await generatePdf(structuredResume);
// Instead of: const pdfBytes = renderPseudoPdfContent(fullName, structuredResume);
```

#### Phase 2 Task 2.5d: Test PDF Output
- Generate a sample CV
- Download PDF from S3
- Open in Adobe Reader / macOS Preview
- Verify formatting, spacing, fonts are correct

### When to Do This?
**After Phase 1 (Terraform done) but could do in parallel with Phase 2 (backend improvements)**.
- Low risk (isolated to handler.js)
- Improves user experience immediately
- No dependency on Phase 3 features
- **Suggest**: Do this early in Phase 2

---

## SQS Decoupling: Terraform vs SAM?

### Your Question
"If later I want to decouple the application using SQS for certain endpoints, would it be better to use Terraform only or with SAM?"

### Answer: **Terraform Only**

Here's why SQS decoupling is **perfect for Terraform-only approach**:

### Current Architecture (Synchronous)
```
Client → API Gateway → Lambda (generateCv) → Bedrock
            ↓
         (wait 3-5 seconds)
            ↓
         Return PDF URL
```

**Problem**: User waits for entire CV generation (Bedrock call is slow). Bad UX.

### Improved Architecture (Asynchronous with SQS)
```
Client → API Gateway → Lambda (acceptCvJob)
              ↓
         Write job to SQS
              ↓
         Return jobId immediately
              ↓
         Client polls for status OR uses WebSocket

Worker Lambda ← SQS (event source mapping)
    ↓
 Bedrock (generate CV)
    ↓
 Store in S3 + DynamoDB
    ↓
 Send SNS notification (job complete)
```

### Terraform Implementation (Clean & Simple)

```hcl
# terraform/queues.tf
resource "aws_sqs_queue" "cv_generation_queue" {
  name                       = "hojadevida-cv-generation-${var.stage}"
  visibility_timeout_seconds = 900  # 15 min for Bedrock call
  message_retention_seconds  = 86400  # 1 day
}

# terraform/lambda.tf (acceptCvJob function)
resource "aws_lambda_function" "accept_cv_job" {
  filename         = "backend/functions/accept-cv-job.zip"
  function_name    = "hojadevida-accept-cv-job-${var.stage}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "accept-cv-job.handler"
  runtime          = "nodejs20.x"
  
  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.cv_generation_queue.id
    }
  }
}

# terraform/lambda.tf (processCvJob function - worker)
resource "aws_lambda_function" "process_cv_job" {
  filename         = "backend/functions/process-cv-job.zip"
  function_name    = "hojadevida-process-cv-job-${var.stage}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "process-cv-job.handler"
  runtime          = "nodejs20.x"
  timeout          = 300  # 5 minutes for Bedrock
  
  environment {
    variables = {
      CVS_TABLE  = aws_dynamodb_table.cvs.name
      CVS_BUCKET = aws_s3_bucket.cvs.id
    }
  }
}

# terraform/lambda.tf (Event source mapping: SQS → Lambda)
resource "aws_lambda_event_source_mapping" "sqs_to_process_cv" {
  event_source_arn = aws_sqs_queue.cv_generation_queue.arn
  function_name    = aws_lambda_function.process_cv_job.arn
  batch_size       = 1  # Process one job at a time
  max_concurrency  = 5  # Parallel processing limit
}

# terraform/apigateway.tf (Update POST /cvs/generate to acceptCvJob)
resource "aws_apigatewayv2_integration" "accept_cv_job" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  
  integration_method = "POST"
  integration_uri    = aws_lambda_function.accept_cv_job.invoke_arn
}

resource "aws_apigatewayv2_route" "post_cvs_generate" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /cvs/generate"
  
  target = "integrations/${aws_apigatewayv2_integration.accept_cv_job.id}"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
}

# terraform/sns.tf (Optional: notify user when job complete)
resource "aws_sns_topic" "cv_generation_complete" {
  name = "hojadevida-cv-complete-${var.stage}"
}

resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.cv_generation_complete.arn
  protocol  = "email"
  endpoint  = "user@example.com"  # Could be from DynamoDB user record
}
```

### Implementation Details

#### Backend Code Structure (New)
```
backend/
├── handler.js                    # Current handlers (keep for reference)
├── functions/
│   ├── accept-cv-job.js         # NEW: Validate input + write to SQS
│   └── process-cv-job.js        # NEW: Read from SQS, call Bedrock, store result
├── lib/
│   ├── bedrock.js               # Bedrock prompt + invocation (extracted)
│   └── pdf-generator.js         # PDF generation (from Phase 2)
└── package.json
```

#### accept-cv-job.js (Queue Submission)
```javascript
const { SQS } = require('@aws-sdk/client-sqs');
const { randomUUID } = require('node:crypto');

const sqs = new SQS();

exports.handler = async (event) => {
  const userId = event.requestContext.authorizer.jwt.claims.sub;
  const cvData = JSON.parse(event.body);
  
  const jobId = randomUUID();
  
  // Write to SQS
  await sqs.sendMessage({
    QueueUrl: process.env.SQS_QUEUE_URL,
    MessageBody: JSON.stringify({
      jobId,
      userId,
      cvData,
      submittedAt: new Date().toISOString(),
    }),
  });
  
  // Return immediately with jobId
  return {
    statusCode: 202,  // Accepted (async)
    body: JSON.stringify({
      message: 'CV generation submitted',
      jobId,
      statusUrl: `/cvs/jobs/${jobId}`,  // Client polls this
    }),
  };
};
```

#### process-cv-job.js (Worker)
```javascript
const { DynamoDB } = require('@aws-sdk/client-dynamodb');
const { S3 } = require('@aws-sdk/client-s3');
const { generatePdf } = require('../lib/pdf-generator');
const { callBedrock } = require('../lib/bedrock');

exports.handler = async (event) => {
  for (const record of event.Records) {
    const { jobId, userId, cvData } = JSON.parse(record.body);
    
    try {
      // Call Bedrock
      const resumeJson = await callBedrock(cvData);
      
      // Generate PDF
      const pdfBytes = await generatePdf(resumeJson);
      
      // Store in S3
      const s3Key = `${userId}/${jobId}.pdf`;
      await s3.putObject({
        Bucket: process.env.CVS_BUCKET,
        Key: s3Key,
        Body: pdfBytes,
      });
      
      // Store metadata in DynamoDB
      await dynamodb.putItem({
        TableName: process.env.CVS_TABLE,
        Item: {
          userId: { S: userId },
          cvId: { S: jobId },
          s3Key: { S: s3Key },
          status: { S: 'completed' },
          completedAt: { S: new Date().toISOString() },
        },
      });
      
      console.log(`Job ${jobId} completed successfully`);
    } catch (error) {
      console.error(`Job ${jobId} failed:`, error);
      // Could write to DLQ or update status to 'failed'
    }
  }
};
```

### Why NOT SAM for This?

If you used SAM + Terraform hybrid:
- SAM manages Lambda + SQS event source mapping
- Terraform manages DynamoDB + S3 (but SAM also creates these?)
- Now you have **THREE state files**: SAM (CloudFormation), Serverless, Terraform
- **Cross-reference nightmare**: acceptCvJob Lambda needs SQS queue URL, but it's in SAM's CF template, not Terraform state

**With Terraform only**:
- Single `terraform apply` deploys everything
- Lambda can reference SQS ARN directly: `aws_sqs_queue.cv_generation_queue.arn`
- No state sync issues

---

## Architectural Recommendations & Corrections

### 1. **CRITICAL: CORS Configuration** 🔴
**Current Issue**: 
```yaml
httpApi:
  cors:
    allowedOrigins:
      - '*'  # ← SECURITY HOLE
```

**Recommendation**: Restrict to frontend domain
```hcl
# terraform/apigateway.tf
resource "aws_apigatewayv2_api" "http_api" {
  name          = "hojadevida-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins     = ["https://${var.frontend_domain}"]  # ← Specific domain
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_headers     = ["Content-Type", "Authorization"]
    expose_headers    = ["Content-Length"]
    max_age          = 300
    allow_credentials = true
  }
}

# variables.tf
variable "frontend_domain" {
  description = "Frontend domain for CORS (e.g., cv.example.com)"
  default     = "localhost:3000"  # dev
}
```

### 2. **IMPORTANT: Bedrock Prompt Engineering** ⚠️
**Current Issue**: Temperature 0.3 is good, but prompt allows hallucination.

**Better Prompt**:
```javascript
const buildResumePrompt = (cvData) => `
You are a professional resume writer. Transform the provided JSON into a polished resume.

CRITICAL CONSTRAINTS:
1. ONLY include information explicitly provided in the input
2. NEVER invent skills, achievements, or experience
3. NEVER hallucinate dates, company names, or metrics
4. If a field is empty, omit that section or write "Not Provided"
5. Emphasize achievements that align with: "${cvData.personalInfo.desiredRole.title}"
6. Return ONLY valid JSON, no markdown

Desired Role: ${cvData.personalInfo.desiredRole.title}
Desired Role Description: ${cvData.personalInfo.desiredRole.description}

Input Data:
${JSON.stringify(cvData, null, 2)}

Output Format:
{
  "Header": "Name | Location | Email | Phone | LinkedIn | GitHub",
  "Summary": "2-3 sentences highlighting alignment with desired role",
  "Experience": "Formatted bullet points (only from provided data)",
  "Skills": "Categorized by relevance to desired role (only provided skills)",
  "Education": "Degree, institution, graduation date",
  "Certifications": "If provided",
  "Languages": "If provided",
  "Additional": "Additional information or portfolio links"
}`;
```

### 3. **MEDIUM: Input Validation on Backend** ⚠️
**Current Issue**: `handler.js` only checks if `cvData` exists, no schema validation.

**Recommendation**: Add validation middleware
```javascript
// backend/lib/validation.js
const validateCvData = (cvData) => {
  const required = [
    'personalInfo.fullName',
    'personalInfo.email',
    'personalInfo.desiredRole.title'
  ];
  
  for (const field of required) {
    const value = field.split('.').reduce((obj, key) => obj?.[key], cvData);
    if (!value) throw new Error(`Missing required field: ${field}`);
  }
  
  // Reject if experiences AND skills both empty
  if ((!cvData.experiences || cvData.experiences.length === 0) &&
      (!cvData.skills || cvData.skills.length === 0)) {
    throw new Error('Must provide at least one experience or skill');
  }
  
  // Reject excessive payload (prevent token waste)
  const jsonSize = JSON.stringify(cvData).length;
  if (jsonSize > 50000) {  // 50KB max
    throw new Error('CV data too large (max 50KB)');
  }
  
  return true;
};

// backend/handler.js
exports.generateCv = async (event) => {
  try {
    validateCvData(cvData);  // ← Add this
    // ... rest of function
  } catch (error) {
    return response(400, { message: error.message });
  }
};
```

### 4. **MEDIUM: DynamoDB Secondary Index for Queries** ⚠️
**Current Issue**: Can only query by userId. Hard to implement:
- "All CVs from last week"
- "Sort by creation date"

**Recommendation**: Add Global Secondary Index (GSI)
```hcl
# terraform/dynamodb.tf
resource "aws_dynamodb_table" "cvs" {
  name           = "hojadevida-cvs-${var.stage}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "cvId"
  
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
  
  # GSI: Query by userId, sorted by creation date
  global_secondary_index {
    name            = "userIdCreatedAtGSI"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }
}
```

Now backend can do:
```javascript
const queryResult = await docClient.send(
  new QueryCommand({
    TableName: TABLE_NAME,
    IndexName: "userIdCreatedAtGSI",
    KeyConditionExpression: "userId = :userId AND createdAt > :weekAgo",
    ExpressionAttributeValues: {
      ":userId": userId,
      ":weekAgo": new Date(Date.now() - 7*24*60*60*1000).toISOString(),
    },
    ScanIndexForward: false,  // Descending (newest first)
  })
);
```

### 5. **IMPORTANT: S3 Bucket Encryption & Lifecycle** ⚠️
**Current Issue**: No encryption at rest, no cleanup policy.

**Recommendation**: 
```hcl
# terraform/s3.tf
resource "aws_s3_bucket" "cvs" {
  bucket = "hojadevida-cvs-${var.stage}"
}

# Enable versioning (for recovery)
resource "aws_s3_bucket_versioning" "cvs" {
  bucket = aws_s3_bucket.cvs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "cvs" {
  bucket = aws_s3_bucket.cvs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "cvs" {
  bucket                  = aws_s3_bucket.cvs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: Delete old versions after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "cvs" {
  bucket = aws_s3_bucket.cvs.id
  
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
  
  # Optional: Archive to Glacier after 1 year
  rule {
    id     = "archive-old-pdfs"
    status = "Enabled"
    
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}
```

### 6. **IMPORTANT: DynamoDB Point-in-Time Recovery (PITR)** ⚠️
**Current Issue**: No backup/recovery mechanism.

**Recommendation**:
```hcl
# terraform/dynamodb.tf
resource "aws_dynamodb_table" "cvs" {
  # ... existing config ...
  
  point_in_time_recovery_specification {
    enabled = true
  }
  
  ttl {
    attribute_name = "expirationTime"
    enabled        = true
  }
}
```

Now DynamoDB keeps 35-day backup history. Can restore to any point in time.

### 7. **GOOD: Lambda Reserved Concurrency** ✅
**Observation**: You might have uncontrolled Lambda scaling (cold starts).

**Recommendation** (for prod):
```hcl
# terraform/lambda.tf
resource "aws_lambda_reserved_concurrent_executions" "generate_cv" {
  function_name                     = aws_lambda_function.generate_cv.function_name
  reserved_concurrent_executions    = 10  # Max 10 concurrent invocations
}
```

This prevents runaway costs from Lambda scaling infinitely. Trade-off: requests beyond limit get throttled (return 429).

### 8. **MEDIUM: Lambda Environment Variable Security** ⚠️
**Current Issue**: Secrets (Bedrock, S3, DynamoDB access) hardcoded in environment.

**Recommendation**: Use AWS Secrets Manager
```hcl
# terraform/secrets.tf
resource "aws_secretsmanager_secret" "bedrock_config" {
  name = "hojadevida/bedrock-config-${var.stage}"
}

resource "aws_secretsmanager_secret_version" "bedrock_config" {
  secret_id = aws_secretsmanager_secret.bedrock_config.id
  secret_string = jsonencode({
    model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
    max_tokens    = 1800
    temperature   = 0.3
  })
}

# terraform/lambda.tf
resource "aws_lambda_function" "generate_cv" {
  # ... existing config ...
  
  # Add permission to read secret
  depends_on = [aws_iam_role_policy.lambda_secrets]
}

# terraform/iam.tf
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "lambda-secrets-policy"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = aws_secretsmanager_secret.bedrock_config.arn
    }]
  })
}

# backend/handler.js
const getBedrockConfig = async () => {
  const secret = await secretsManagerClient.getSecretValue({
    SecretId: process.env.BEDROCK_CONFIG_SECRET,
  });
  return JSON.parse(secret.SecretString);
};
```

Not critical now, but essential before production with real credentials.

### 9. **GOOD: CloudWatch Alarms Missing** ⚠️
**Recommendation**: Set up basic monitoring
```hcl
# terraform/cloudwatch.tf
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "hojadevida-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda has >5 errors in 5 minutes"
  
  dimensions = {
    FunctionName = aws_lambda_function.generate_cv.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "bedrock_throttle" {
  alarm_name          = "hojadevida-bedrock-throttle"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "ModelThrottlingExceeded"
  namespace           = "AWS/Bedrock"
  # ...
}
```

### 10. **OBSERVATION: Frontend Environment Variables** ✅
**Current**: Frontend Dockerfile passes env vars at build time.

**Better**: Pass at runtime OR build time with clear defaults
```dockerfile
# frontend/Dockerfile.prod
ARG NEXT_PUBLIC_API_URL=http://localhost:3000/api
ARG NEXT_PUBLIC_COGNITO_USER_POOL_ID=local-dev
ARG NEXT_PUBLIC_COGNITO_CLIENT_ID=local-dev

ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_COGNITO_USER_POOL_ID=${NEXT_PUBLIC_COGNITO_USER_POOL_ID}
ENV NEXT_PUBLIC_COGNITO_CLIENT_ID=${NEXT_PUBLIC_COGNITO_CLIENT_ID}

RUN npm run build
```

Pass from GitHub Actions:
```yaml
# .github/workflows/deploy.yml
- run: docker build . \
    --build-arg NEXT_PUBLIC_API_URL=${{ secrets.API_URL }} \
    --build-arg NEXT_PUBLIC_COGNITO_USER_POOL_ID=${{ secrets.COGNITO_POOL_ID }} \
    --build-arg NEXT_PUBLIC_COGNITO_CLIENT_ID=${{ secrets.COGNITO_CLIENT_ID }}
```

---

## Summary Table: Recommendations vs Current

| Area | Current | Recommendation | Priority | Impact |
|------|---------|-----------------|----------|--------|
| IaC | Serverless + CloudFormation split | Terraform only | 🔴 CRITICAL | Enable SQS decoupling, single state |
| CORS | Allows all (`*`) | Restrict to frontend domain | 🔴 CRITICAL | Security vulnerability |
| PDF | Text rendering | pdfkit library | 🟡 HIGH | Better UX |
| Bedrock Prompt | Basic, may hallucinate | Enhanced with constraints | 🟡 HIGH | More accurate CVs |
| Input Validation | Minimal | Full schema validation | 🟡 HIGH | Prevent errors |
| DynamoDB Queries | Only by userId | Add GSI for date filtering | 🟠 MEDIUM | Enable future features |
| S3 Encryption | None | AES-256 + lifecycle policy | 🟡 HIGH | Security + cost savings |
| DynamoDB Backup | None | Enable PITR | 🟠 MEDIUM | Data recovery |
| Secrets Management | Env vars only | AWS Secrets Manager | 🟠 MEDIUM | Production readiness |
| Monitoring | None | CloudWatch alarms | 🟠 MEDIUM | Cost control + incident response |
| Lambda Concurrency | Unlimited | Reserved concurrency (prod) | 🟠 MEDIUM | Cost predictability |

---

## Updated Phase 1: Terraform-Only Approach

**Duration**: 6-8 days (slightly longer, but more comprehensive)

**Includes**:
- Backend: Lambda, API Gateway, DynamoDB, S3
- Frontend: ECS, ALB, VPC, security groups
- Auth: Cognito, OIDC
- Security: IAM roles, permission boundaries
- Monitoring: CloudWatch logs, alarms
- State: S3 backend + DynamoDB locks

**Deliverable**: Single `terraform apply` deploys entire application

---

**Ready to start Phase 1 with this refined approach?**
