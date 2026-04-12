# Implementation Plan — Hojadevida-izador

## Overview
This document breaks down the TODO.md requirements into controlled, testable phases that can be validated and deployed incrementally. Each phase builds on the previous one and maintains system stability.

---

## Phase 1: Refactor Infrastructure to Terraform
**Purpose**: Replace CloudFormation with Terraform for better readability and maintainability.
**Criticality**: HIGH (affects all subsequent deployments)
**Effort**: 5-7 days
**Testing**: CloudFormation → Terraform comparison; parallel deployment validation

### Tasks:
1. **Create Terraform Structure** (`/terraform`)
   - `main.tf`: Cognito User Pool, Client
   - `dynamodb.tf`: DynamoDB table for CVs
   - `s3.tf`: S3 bucket for PDFs
   - `iam.tf`: Execution roles and policies
   - `lambda.tf`: Lambda functions (reference backend package)
   - `apigateway.tf`: HTTP API and authorizer
   - `outputs.tf`: Export values for frontend (API endpoint, Cognito IDs)
   - `variables.tf`: Variables (region, stage, etc.)
   - `terraform.tfvars`: Environment-specific values

2. **Outputs Mapping**
   - Map CloudFormation outputs to Terraform outputs
   - Ensure GitHub Actions can read outputs
   - Update deploy script to use `terraform output` instead of CloudFormation

3. **GitHub Actions Pipeline Update**
   - Modify `.github/workflows/deploy.yml` to run Terraform
   - Add `terraform init`, `terraform plan`, `terraform apply`
   - Store Terraform state in S3 with DynamoDB locking

4. **Validation**
   - Deploy to dev stage using Terraform
   - Verify Lambda functions are invoked correctly
   - Confirm DynamoDB and S3 resources match old setup
   - Test Cognito authentication flow
   - **Rollback to CloudFormation if needed**

5. **Cleanup**
   - Once validated, deprecate old CloudFormation templates
   - Document migration steps in README

---

## Phase 2: Backend Enhancements
**Purpose**: Improve backend reliability, prompt quality, and API robustness.
**Criticality**: MEDIUM
**Effort**: 3-4 days
**Testing**: Unit tests for each handler, integration tests with Bedrock mock

### Tasks:

#### 2.1: Improve Bedrock Prompt (Prevent Hallucination)
**Goal**: Ensure AI only includes verified skills and avoids inventing information.

- **Current Issue**: Bedrock may add skills not mentioned by user if they align with desired role
- **Solution**:
  - Modify `buildResumePrompt()` in `handler.js`
  - Add explicit instruction: *"Only include skills, experiences, and achievements that are explicitly provided in the input. Do NOT invent or assume additional experiences. If a section is empty, leave it as 'Not provided' rather than fabricating content."*
  - Add role-specific guidance: *"For the {desiredRole.title} position, highlight only the achievements and skills that directly align with this role from the provided data."*
  - Test with sample inputs to verify compliance

#### 2.2: Add Social Media Support
**Goal**: Store GitHub and LinkedIn URLs in CV data.

- Create new optional field structure in backend:
  ```javascript
  socials: {
    github: "https://github.com/username",
    linkedin: "https://linkedin.com/in/username"
  }
  ```
- Update `renderPseudoPdfContent()` to include socials in header (formatted as clickable URLs)
- Include in Bedrock prompt: *"Include GitHub and LinkedIn URLs if provided in the socials object."*

#### 2.3: Add Input Validation
**Goal**: Reject malformed requests early.

- Validate `cvData` structure against expected schema
- Check required fields (personalInfo, at least one experience/skill)
- Reject excessive data (prevent token waste)
- Return 400 with detailed error messages
- Test with invalid/edge case inputs

#### 2.4: Improve Error Handling
**Goal**: Return meaningful error messages to frontend.

- Distinguish between client errors (400) and server errors (500)
- Log full error context (Bedrock response, DynamoDB issues)
- Return user-friendly messages without exposing AWS internals
- Add retry logic for transient S3/DynamoDB failures

#### 2.5: PDF Generation Enhancement (Optional)
**Goal**: Consider upgrading from text rendering to actual PDF.

- Evaluate `pdfkit` npm package for PDF generation
- Update handler to generate proper PDF with:
  - Header with name, contact info, socials (GitHub/LinkedIn links)
  - Sections with bold titles and horizontal dividers
  - Proper spacing and page breaks
- If pdfkit adds too much complexity, defer to Phase 4

#### 2.6: Test Strategy
- Unit tests: `handler.js` with mocked Bedrock/DynamoDB/S3
- Integration test: Spin up LocalStack (mock AWS), verify full flow
- Load test: Generate 10 CVs rapidly, verify no rate limit issues
- Bedrock test: Compare text output from multiple prompt variations

---

## Phase 3: Frontend Features
**Purpose**: Complete form wizard, add CVs listing page, improve navigation.
**Criticality**: HIGH (user-facing features)
**Effort**: 5-6 days
**Testing**: E2E tests using Playwright/Cypress, manual testing with Cognito sandbox

### Tasks:

#### 3.1: Form Wizard — Add Back Button and Navigation
**Goal**: Users can navigate within the form wizard.

- Add "Previous" button to each form step (disabled on first step)
- Add "Skip" button for optional sections (languages, certifications)
- Add "Home" button in top-right (with confirmation modal)
- Update FormWizard component state to track current step history
- Test navigation flow and form data persistence

#### 3.2: Add Social Media Section to Form
**Goal**: Collect GitHub and LinkedIn URLs.

- Create new form step: `SocialsStep.tsx`
- Fields: GitHub URL (optional), LinkedIn URL (optional)
- Validate URLs (basic format check: must start with https://)
- Store in FormWizard state as `socials: { github?, linkedin? }`
- Include in final CV data sent to backend
- Test form validation and data passing

#### 3.3: Implement CVs Listing Page (`/cvs`)
**Goal**: Show all CVs created by the logged-in user.

- Create `/frontend/app/cvs/page.tsx`
- Fetch CVs from `GET /cvs` endpoint (protected)
- Display as card grid with:
  - CV name
  - Created date (formatted)
  - "Download" button (opens presigned URL)
  - "Delete" button (optional, requires backend endpoint)
- Add pagination if user has >50 CVs
- Show "No CVs yet" message if empty
- Add link in Navbar to `/cvs` page
- Test Cognito authentication check before rendering

#### 3.4: Update Navbar
**Goal**: Make navigation consistent across pages.

- Add link to `/cvs` page (logged-in users only)
- Show "Login" / "Logout" buttons conditionally
- Show user's email when logged in
- Add breadcrumb navigation (Home → Create CV → My CVs)
- Test on mobile (responsive design)

#### 3.5: Improve Form Wizard UX
**Goal**: Better user feedback and data handling.

- Show progress percentage at top
- Auto-save form data to localStorage (recover if page refresh)
- Add "Save Draft" button (optional)
- Show confirmation modal before leaving without saving
- Add loading spinner when sending to backend
- Display Bedrock-generated summary before download
- Test data recovery and error states

#### 3.6: Pass Configuration to Frontend
**Goal**: Frontend knows backend endpoint and Cognito settings dynamically.

- Backend Terraform exports: `http_api_url`, `cognito_user_pool_id`, `cognito_client_id`
- Frontend reads from environment variables (injected at build time or runtime)
- Update `.env.local.example` with required variables:
  ```
  NEXT_PUBLIC_API_URL=https://xxx.execute-api.us-east-1.amazonaws.com
  NEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_xxx
  NEXT_PUBLIC_COGNITO_CLIENT_ID=xxx
  ```
- Dockerfile build process injects these during image creation
- Update Amplify config to use dynamic values

#### 3.7: Test Strategy
- Unit tests: Individual form components with Jest
- E2E tests: Playwright tests for full user flow (form → submit → download)
- Accessibility: Lighthouse audit, WAVE tool for a11y
- Cross-browser: Chrome, Firefox, Safari
- Mobile: Test on iPhone and Android sizes

---

## Phase 4: Deployment Pipeline
**Purpose**: Automate frontend and backend deployments.
**Criticality**: HIGH
**Effort**: 3-4 days
**Testing**: Manual deployment to dev stage, automated tests in CI

### Tasks:

#### 4.1: Backend Deployment (Terraform + GitHub Actions)
**Status**: Already working (via Serverless), but needs Terraform migration
- Execute Phase 1 tasks
- Update deploy workflow to call `terraform apply`
- Add approval step for prod deployments

#### 4.2: Frontend Deployment (ECS Fargate + CloudFront)
**Goal**: Deploy Next.js app to AWS infrastructure.

- **Option A**: ECS Fargate + ALB (recommended for this stack)
  - Create Dockerfile (already exists: `Dockerfile.prod`)
  - Push to ECR via GitHub Actions
  - Create ECS task definition and service (Terraform module)
  - Attach ALB with HTTP/HTTPS
  - Optionally front with CloudFront

- **Option B**: S3 + CloudFront (simpler, but requires backend for API)
  - `next build && next export` to generate static site
  - Upload to S3
  - CloudFront for caching and CDN
  - **Issue**: Next.js dynamic routes may not export to static

- **Recommended**: Option A (Fargate) for flexibility

- **Steps**:
  1. Create `terraform/frontend.tf` (ECR repo, ECS cluster, service, ALB)
  2. Update `.github/workflows/deploy.yml`:
     - Build image: `docker build -f frontend/Dockerfile.prod -t hojadevida-izador:$COMMIT_SHA`
     - Push to ECR: `aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URL`
     - Update ECS service to pull new image
  3. Pass Terraform outputs (API endpoint, Cognito IDs) as Docker build args
  4. Test: Deploy to dev, verify frontend can call backend

#### 4.3: GitHub Actions Secrets Management
**Goal**: Store credentials safely for CI/CD.

Already using OIDC, but need additional secrets:
- `AWS_ROLE_ARN`: OIDC role ARN (already documented in README)
- `AWS_REGION`: us-east-1 (default, can be repo variable)
- `ECR_REPOSITORY`: ECR repository name
- `TF_BACKEND_BUCKET`: S3 bucket for Terraform state
- `TF_LOCK_TABLE`: DynamoDB table for Terraform locks

Document in README and GitHub repo settings.

#### 4.4: Environment Management
**Goal**: Separate dev, staging, and prod environments.

- Terraform workspaces or separate tfvars files for each stage
- GitHub Actions: Create workflow dispatch option to choose stage
- Or: Use branch strategy (main → prod, develop → staging, feature → dev)
- Each stage has separate Cognito, DynamoDB, S3, ECR repositories

#### 4.5: Monitoring & Logging
**Goal**: Observe deployments and catch errors.

- CloudWatch Logs: Configure log group for Lambda and ECS
- Terraform: Export log group names for reference
- GitHub Actions: Add `actions/upload-logs@v1` to capture deployment logs
- Alert: Set up SNS notifications for deployment failures

#### 4.6: Database Migrations & Backups
**Goal**: Safe schema changes.

- DynamoDB: Define schema in Terraform (hash + range keys)
- For future changes: Use AWS DMS or custom Lambda scripts
- Backups: Enable point-in-time recovery (PITR) for DynamoDB
- Document backup/restore process

#### 4.7: Test Strategy
- Deploy to dev stage, run smoke tests
- Deploy to staging, run full E2E tests
- Manual approval before prod deployment
- Rollback plan: Keep previous ECR image tag for fast rollback

---

## Phase 5: Advanced Features & Polish
**Purpose**: Add optional enhancements after core functionality is stable.
**Criticality**: LOW
**Effort**: 5-7 days (can be split across multiple releases)

### Tasks (Prioritized):

#### 5.1: CV Deletion
- Add `DELETE /cvs/{cvId}` endpoint
- Delete from DynamoDB and S3
- Frontend "Delete" button in CVs listing
- Confirmation modal before deletion

#### 5.2: CV Editing
- Store original form data with each CV (optional)
- Allow user to "Edit" CV and regenerate
- Update `/cvs/{cvId}/update` endpoint
- Preserve cvId but update S3 PDF and DynamoDB metadata

#### 5.3: Advanced PDF Generation
- Upgrade `pdfkit` implementation for professional formatting
- Add themes/templates (Harvard, Modern, Minimalist)
- User can download as PDF or Word (.docx)
- Export to LinkedIn profile

#### 5.4: Real CV Data Pre-filling
- Allow users to import from LinkedIn or GitHub API
- Auto-extract: name, email, education, skills, work history
- Pre-populate form to reduce manual entry

#### 5.5: A/B Testing
- Test different Bedrock prompts
- Measure user satisfaction, download rate
- Gradually shift to better-performing prompt

#### 5.6: Analytics
- Track: CVs generated, users created, avg time to download
- CloudWatch metrics or third-party (Segment, Mixpanel)
- Dashboards for business insights

#### 5.7: Cost Optimization
- Analyze Bedrock token usage per CV
- Consider switching to Claude 3.5 Haiku (cheaper, better quality)
- Set up S3 lifecycle policy (archive old PDFs after 1 year)
- Enable DynamoDB auto-scaling or reserved capacity

---

## Validation Strategy for Each Phase

### Phase 1 (Infrastructure)
- [ ] Terraform plan output matches CloudFormation resources
- [ ] Deploy to dev stage with Terraform
- [ ] Verify Lambda invocation: `aws lambda invoke --function-name listCvs /tmp/response.json`
- [ ] Test Cognito flow manually (sign up, sign in)
- [ ] Confirm DynamoDB table and S3 bucket created
- [ ] Check CloudFormation stack is replaced by Terraform state

### Phase 2 (Backend)
- [ ] Unit tests pass: `npm test` in `/backend`
- [ ] Integration test: Create mock event, invoke handler locally
- [ ] Bedrock prompt test: Sample input → output has no hallucinations
- [ ] Social media field parsed correctly
- [ ] Input validation rejects bad data (400 status)
- [ ] Error handling returns user-friendly messages

### Phase 3 (Frontend)
- [ ] Form wizard navigation: Back button works, state preserved
- [ ] Socials form step renders and validates URLs
- [ ] CVs listing page: Fetches and displays CVs (authenticated)
- [ ] Navbar shows login/logout, links to new pages
- [ ] E2E test: Create CV → View in /cvs → Download
- [ ] Mobile responsive: Form readable on iPhone 12 size
- [ ] Accessibility: No console errors, WAVE audit passes

### Phase 4 (Deployment)
- [ ] GitHub Actions workflow runs without errors
- [ ] Frontend Docker image builds successfully
- [ ] ECS task starts and serves traffic
- [ ] Frontend can reach backend API (test XHR in browser console)
- [ ] CloudFormation outputs exported to Terraform outputs
- [ ] Rollback procedure tested (old image restored)

### Phase 5 (Advanced Features)
- [ ] Each feature has unit + E2E tests
- [ ] No regression: existing CVs still downloadable
- [ ] Performance: Page load time <3 seconds
- [ ] Cost analysis: Monthly AWS bill reviewed

---

## Timeline Estimate

| Phase | Start | Duration | End | Blocker |
|-------|-------|----------|-----|---------|
| **Phase 1**: Terraform | Week 1 | 5-7 days | ~Day 7 | None |
| **Phase 2**: Backend | Week 2 | 3-4 days | ~Day 11 | Phase 1 |
| **Phase 3**: Frontend | Week 2-3 | 5-6 days | ~Day 16 | Phase 2 (partially) |
| **Phase 4**: Deployment | Week 3 | 3-4 days | ~Day 19 | Phase 1, 2, 3 |
| **Phase 5**: Advanced | Week 4+ | 5-7 days | Ongoing | Phase 4 |

**Total**: ~4-5 weeks for Phases 1-4 (core functionality)

---

## Risk Assessment & Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|-----------|
| Terraform state gets corrupted | HIGH | LOW | S3 backend with versioning + DynamoDB locks |
| Bedrock API rate limit | MEDIUM | MEDIUM | Add exponential backoff, request queuing |
| Lambda cold start delays CV generation | MEDIUM | HIGH | Provisioned concurrency (expensive) or accept delays |
| Frontend/backend version mismatch | MEDIUM | MEDIUM | Version API, feature flags in frontend |
| Data loss in S3/DynamoDB | CRITICAL | VERY LOW | Enable PITR, versioning, regular backups |
| Security vulnerability in dependencies | HIGH | MEDIUM | Dependabot alerts, monthly audits |
| Cost explosion (Bedrock/Lambda) | MEDIUM | MEDIUM | Set up CloudWatch alarms, implement rate limiting |

---

## Rollback Plan

If any phase fails or causes production outage:

1. **Phase 1 (Terraform)**: Revert to CloudFormation, keep both running in parallel until confident
2. **Phase 2 (Backend)**: Revert `handler.js` to last working commit, redeploy via Serverless
3. **Phase 3 (Frontend)**: Deploy previous ECR image tag, clear CloudFront cache
4. **Phase 4 (Deployment)**: Keep ECS service pointing to previous task definition, update service in Terraform
5. **Phase 5 (Features)**: Feature flags in code; toggle off problematic feature without redeployment

---

## Success Criteria

- ✅ All TODO.md items implemented
- ✅ Zero data loss or security incidents
- ✅ >95% test coverage on critical paths
- ✅ Frontend load time <2.5 seconds (Core Web Vitals)
- ✅ Monthly AWS cost <$50 (with reasonable usage)
- ✅ Zero production downtime during rollout
- ✅ Team can deploy changes in <30 minutes
- ✅ User feedback: CVs generated are professional and accurate

---

**Next Action**: Review this plan with stakeholders, adjust phases as needed, and begin Phase 1.
