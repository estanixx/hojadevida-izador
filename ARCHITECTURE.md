# Hojadevida-izador Architecture & Context

## Overview
**Hojadevida-izador** is an **AI-powered CV/Resume generator** that helps users create professional, formatted CVs using generative AI. The application follows a modern three-tier serverless architecture with user authentication, AI-powered content generation, and secure document storage.

### Value Proposition
- **Intelligent CV Creation**: Uses AWS Bedrock (Claude 3 Haiku) to transform user input into professionally formatted resumes
- **User-Specific Storage**: Every CV is stored securely per user with Cognito authentication
- **Instant Downloads**: Presigned S3 URLs provide secure, temporary access to generated PDFs
- **Guided Experience**: Multi-step form wizard ensures users provide all necessary information

---

## Architecture Layers

### 1. **Frontend** (Next.js 16 + React 19)
**Location**: `/frontend`
**Tech Stack**: TypeScript, Tailwind CSS, AWS Amplify Auth, GSAP animations

#### Key Pages:
- **`/` (Home)**: Landing page with animated title and "Create your CV" call-to-action
- **`/create-cv`**: Protected form wizard where users input CV data through multi-step process
- **`/cvs`** (Planned): List all CVs created by the authenticated user

#### Current Components:
- `Navbar`: Navigation component
- `FormWizard`: Multi-step form with steps in `/components/steps/`
- `ProgressBar`: Visual progress indicator
- `AmplifyProvider`: AWS Amplify configuration wrapper

#### Authentication:
- Uses AWS Cognito via AWS Amplify SDK (`@aws-amplify/auth`)
- Frontend authenticates before accessing protected routes
- JWT tokens in Authorization header for backend calls
- Function `isAuthenticated()` in `/lib/auth` checks login status

#### Data Flow:
```
User Input → FormWizard → /api/cvs/generate (Backend Lambda)
                               ↓
                        Bedrock API (AI Processing)
                               ↓
                        S3 Storage (PDF) + DynamoDB (Metadata)
```

---

### 2. **Backend** (Node.js 20 Lambda Functions)
**Location**: `/backend`
**Framework**: Serverless Framework (AWS Lambda + API Gateway)
**Runtime**: Node.js 20.x
**Region**: us-east-1

#### API Endpoints:
1. **`GET /cvs`** (Protected by Cognito JWT)
   - **Handler**: `handler.listCvs`
   - **Function**: Returns all CVs created by the authenticated user
   - **Response**: Array of CV metadata with presigned download URLs
   - **Auth**: Extracts userId from JWT claims (`event.requestContext.authorizer.jwt.claims.sub`)

2. **`POST /cvs/generate`** (Protected by Cognito JWT)
   - **Handler**: `handler.generateCv`
   - **Input**: CV data object (personalInfo, experiences, skills, languages, etc.)
   - **Process**:
     - Validates CV data structure
     - Generates prompt for Claude 3 Haiku via AWS Bedrock
     - Invokes Bedrock model with controlled parameters (temp: 0.3, max_tokens: 1800)
     - Extracts structured resume JSON from model response
     - Renders pseudo-PDF content to text file
     - Stores PDF in S3
     - Saves metadata to DynamoDB
   - **Response**: CV metadata with presigned download URL

#### Key Functions:
- `buildResumePrompt()`: Constructs the prompt instructing Bedrock to generate Harvard-style resume
- `extractResumeJson()`: Parses Bedrock response and validates JSON
- `renderPseudoPdfContent()`: Formats structured resume data into readable text document
- `buildSignedUrl()`: Generates 15-minute presigned S3 URLs for secure downloads
- `getUserId()`: Extracts user ID from JWT claims

#### Environment Variables:
- `CVS_TABLE`: DynamoDB table name (injected from CloudFormation)
- `CVS_BUCKET`: S3 bucket name (injected from CloudFormation)

---

### 3. **Infrastructure** (AWS CloudFormation via Serverless)
**Location**: `/infrastructure` + embedded resources in `/backend/serverless.yaml`

#### Managed Resources:

**Database**:
- **DynamoDB Table** (`hojadevida-izador-table-{stage}`)
  - Partition Key: `userId` (User from Cognito)
  - Sort Key: `cvId` (UUID)
  - Items: `{ userId, cvId, name, s3Link, s3Key, createdAt }`
  - Billing: Pay-per-request (scales with usage)

**Storage**:
- **S3 Bucket** (`hojadevida-izador-cvs-{stage}`)
  - Objects: `{userId}/{cvId}.pdf`
  - Access: Private bucket + presigned URLs
  - Lifecycle: No retention policy defined (consider for cost optimization)

**Authentication**:
- **Cognito User Pool** (`hojadevida-izador-users-{stage}`)
  - Username attribute: email
  - Auto-verified email
- **Cognito User Pool Client**
  - Auth Flows: User SRP (Secure Remote Password), Refresh Token
  - Prevents user enumeration attacks

**API**:
- **HTTP API** (API Gateway v2)
  - JWT authorizer via Cognito
  - Issuer: `https://cognito-idp.{region}.amazonaws.com/{UserPoolId}`
  - Audience: Cognito Client ID
  - CORS enabled (currently allows all origins `*`)

**IAM**:
- Lambda execution role with minimal permissions:
  - DynamoDB: PutItem, Query, GetItem
  - S3: PutObject, GetObject
  - Bedrock: InvokeModel (all models)

#### Deployment:
- **Serverless Framework** orchestrates CloudFormation
- **GitHub Actions** (via OIDC trust relationship)
- **Outputs** exported for frontend consumption:
  - `Hojadevida-HttpApiUrl`: Backend API endpoint
  - `Hojadevida-UserPoolId`: Cognito User Pool ID
  - `Hojadevida-UserPoolClientId`: Cognito Client ID

---

## Data Model

### CV Data Structure (Input)
```json
{
  "personalInfo": {
    "fullName": "string",
    "email": "string",
    "phone": "string",
    "location": "string",
    "desiredRole": {
      "title": "string",
      "description": "string"
    }
  },
  "experiences": [
    {
      "id": "uuid",
      "enterpriseName": "string",
      "fromDate": "string",
      "toDate": "string",
      "metrics": "string",
      "achievements": "string"
    }
  ],
  "skills": ["string"],
  "languages": [
    {
      "id": "uuid",
      "language": "string",
      "proficiencyLevel": "string"
    }
  ],
  "education": ["string"],
  "certifications": ["string"],
  "additionalInformation": "string",
  "summary": "string"
}
```

### Generated Resume (Output)
```json
{
  "Header": "string (formatted with name, email, location, phone, LinkedIn, GitHub)",
  "Summary": "string",
  "Experience": "string (formatted achievements with metrics)",
  "Skills": "string (categorized and highlighted)",
  "Education": "string",
  "Certifications": "string",
  "Languages": "string",
  "Additional": "string",
  "pdfLayout": "string (instructions for PDF formatting)"
}
```

---

## Current State & Technical Debt

### ✅ What Works
- Basic CV generation using Bedrock Claude 3 Haiku
- Cognito authentication flow
- DynamoDB storage for CV metadata
- S3 storage with presigned URLs
- GitHub OIDC trust relationship for CI/CD

### ⚠️ Known Limitations
1. **Frontend Routes**: Only `/create-cv` exists; `/cvs` listing page not implemented
2. **Navigation**: No back button in form wizard; no way to return to home from creation flow
3. **CV Data Schema**: Missing `socials` object for GitHub/LinkedIn links
4. **CV Content**: Bedrock response is rendered as plain text, not actual PDF
5. **Role-Based Content**: Prompt doesn't prevent AI from inventing skills not aligned with desired role
6. **Infrastructure**: CloudFormation scattered across multiple files; no Terraform equivalent
7. **Deployment**: No frontend deployment pipeline defined; only backend via Serverless

### 🔴 Architectural Issues to Address
1. **CORS Configuration**: Allows all origins (`*`) — security risk in production
2. **S3 Bucket Lifecycle**: No retention policy; CVs accumulate indefinitely
3. **Bedrock Tokens**: Temperature 0.3 is good, but prompt engineering could prevent hallucination better
4. **Presigned URLs**: 15-minute expiration may be too short for downloads; consider adjusting
5. **DynamoDB Queries**: Only supports query by userId; no global secondary indexes for filtering by date

---

## Deployment & CI/CD

### Current Setup
- **IaC**: CloudFormation in `/infrastructure`
- **OIDC Provider**: GitHub Actions → AWS via OIDC (no long-lived credentials)
- **Backend Deploy**: `npm run deploy:prod` → Serverless Framework
- **Frontend Deploy**: **Not configured** (manual or needs setup)

### What's Missing
- Frontend deployment pipeline (should use CloudFront + S3 or ECS Fargate)
- Terraform equivalent of CloudFormation templates
- Environment variable passing to frontend (API endpoint, Cognito client ID)
- Automated testing in CI/CD

---

## Technology Choices & Tradeoffs

| Component | Choice | Why | Tradeoff |
|-----------|--------|-----|----------|
| Frontend Framework | Next.js 16 | Full-stack React, built-in auth support, SEO | Larger bundle vs SPA frameworks |
| Backend | Lambda + Serverless | Serverless, managed infrastructure, cost-effective | Cold starts, no persistent connections |
| Database | DynamoDB | Managed NoSQL, scales automatically, integrates with Lambda | No joins, query flexibility limited |
| AI Model | Claude 3 Haiku | Fast inference, cheap, good for text generation | Less capable than Opus; may hallucinate |
| Auth | Cognito | AWS-native, manages tokens, integrates with API Gateway | Vendor lock-in, less customizable than Auth0 |
| IaC | CloudFormation | AWS-native, integrated with Serverless Framework | Verbose YAML, less readable than Terraform |
| PDF Generation | Text rendering | Simple, no external deps | Not actual PDF; text output only |

---

## Security Considerations

### ✅ Current Protections
- JWT authentication via Cognito
- User-scoped data (userId from JWT claims)
- S3 bucket is private; access only via presigned URLs
- Minimal IAM permissions (principle of least privilege)
- OIDC trust for GitHub Actions (no secrets needed)

### ⚠️ Security Gaps
1. **CORS**: Allows all origins; should restrict to frontend domain
2. **API Rate Limiting**: No throttling on CV generation (potential cost abuse)
3. **Bedrock Hallucination**: Prompt doesn't prevent AI from inventing untruthful information
4. **S3 Bucket**: No encryption-at-rest configured; should enable by default
5. **Data Retention**: CVs stored indefinitely; should have archival/deletion policy
6. **Presigned URL Leakage**: 15-minute URLs could be shared; no watermarking or audit log

---

## Next Steps for Implementation

Refer to `/TODO.md` for the complete feature roadmap. Priority changes:

1. **Infrastructure Refactor**: CloudFormation → Terraform
2. **Frontend Navigation**: Add back button + home navigation in form wizard
3. **New Pages**: Implement `/cvs` listing page with authentication
4. **CV Schema**: Add `socials` object (GitHub, LinkedIn)
5. **Bedrock Prompt**: Improve to prevent hallucination and align with desired role
6. **Backend Functions**: Add validation and error handling
7. **PDF Generation**: Consider library like `pdfkit` or external service
8. **Deployment**: Add frontend CI/CD pipeline, pass secrets to frontend via Terraform

---

## File Structure

```
hojadevida-izador/
├── backend/                    # Lambda functions (Node.js)
│   ├── handler.js             # listCvs, generateCv endpoints
│   ├── serverless.yaml        # Infrastructure as Code (CloudFormation)
│   └── package.json
├── frontend/                   # Next.js application
│   ├── app/
│   │   ├── page.tsx           # Home page
│   │   ├── create-cv/page.tsx # Form wizard page
│   │   ├── cvs/page.tsx       # CVs listing (to implement)
│   │   └── layout.tsx
│   ├── components/
│   │   ├── FormWizard.tsx
│   │   ├── Navbar.tsx
│   │   └── steps/             # Form wizard steps
│   ├── lib/auth.ts            # Authentication utilities
│   └── package.json
├── infrastructure/            # CloudFormation YAML
│   ├── initial-account-setup.yaml  # OIDC + IAM
│   ├── github-oidc-provider.yaml  # OIDC provider
│   └── ...
├── .github/
│   └── workflows/             # CI/CD pipelines
├── ARCHITECTURE.md            # This file
├── TODO.md                    # Feature roadmap
└── CVEXAMPLE.md              # Example CV output
```

---

## Key Metrics & Considerations

- **Lambda Cold Start**: First invocation may be 1-3 seconds (acceptable for async CV generation)
- **Bedrock Cost**: Claude 3 Haiku ~$0.25 per 1M input tokens; expect ~500 tokens/CV = $0.0001 per CV
- **DynamoDB Cost**: Pay-per-request; ~1 item write + 1 query per CV = ~$0.001-$0.002 per operation
- **S3 Cost**: ~$0.023 per 1000 PUT requests; negligible for this use case
- **Cognito Cost**: Free for up to 50,000 monthly active users (MAU)

---

**Last Updated**: April 12, 2026  
**Status**: Architecture exploration complete. Ready for implementation roadmap.
