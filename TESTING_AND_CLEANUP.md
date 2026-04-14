# Testing & Cleanup Guide

## Table of Contents
1. [Testing Strategies](#testing-strategies)
2. [Backend Testing](#backend-testing)
3. [Frontend Testing](#frontend-testing)
4. [Infrastructure Testing](#infrastructure-testing)
5. [Cleanup Procedures](#cleanup-procedures)
6. [Quick Reference](#quick-reference)

## Testing Strategies

This project follows the **testing pyramid** approach:
- **Unit Tests** (30-50): Lambda handler logic, no AWS dependencies
- **Integration Tests** (5-10): API endpoints with real AWS services
- **E2E Tests** (1-3): Full user journey (signup → CV generation)

### Quick Links
- **Backend API**: https://4iuqo7wvq1.execute-api.us-east-1.amazonaws.com/dev
- **Cognito Pool**: us-east-1_7pA4zpLch
- **Cognito Client**: 1d1orrgr2fj0pccbiaghl996to

## Backend Testing

### Prerequisites

Create a test user in Cognito:

```bash
USER_POOL_ID="us-east-1_7pA4zpLch"
EMAIL="test@example.com"
PASSWORD="TempPass123!"

# Create user
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username $EMAIL \
  --temporary-password $PASSWORD \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username $EMAIL \
  --password $PASSWORD \
  --permanent
```

### Getting JWT Token

```bash
CLIENT_ID="1d1orrgr2fj0pccbiaghl996to"

TOKEN=$(aws cognito-idp initiate-auth \
  --client-id $CLIENT_ID \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=test@example.com,PASSWORD=TempPass123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

echo $TOKEN
```

### Testing API Endpoints

#### List CVs (GET /cvs)
```bash
API="https://4iuqo7wvq1.execute-api.us-east-1.amazonaws.com/dev"

curl -X GET $API/cvs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

Expected response:
```json
[
  {
    "cvId": "cv-123",
    "userId": "user-456",
    "createdAt": "2026-04-13T21:00:00Z",
    "status": "completed"
  }
]
```

#### Generate CV (POST /cvs/generate)
```bash
curl -X POST $API/cvs/generate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "skills": ["Python", "AWS", "JavaScript"]
  }'
```

Expected response:
```json
{
  "cvId": "cv-456",
  "userId": "user-789",
  "status": "processing",
  "createdAt": "2026-04-13T21:05:00Z"
}
```

#### Authorization Failure Test
```bash
# Call API without token
curl -X GET $API/cvs \
  -H "Content-Type: application/json"
```

Expected: `401 Unauthorized`

### Verifying Data in AWS

Check DynamoDB:
```bash
aws dynamodb scan \
  --table-name hojadevida-cvs-dev \
  --limit 10
```

Check S3:
```bash
aws s3 ls s3://hojadevida-cvs-871696174477-dev/
```

## Frontend Testing

### Get ALB DNS Name

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `hojade`)].DNSName' \
  --output text)

echo "Frontend: http://$ALB_DNS"
```

### Manual E2E Test

1. Open `http://$ALB_DNS` in browser
2. Click "Sign Up"
3. Enter email & password
4. Verify email (check Cognito console or email)
5. Login with credentials
6. Fill CV form:
   - Name: John Doe
   - Email: john@example.com
   - Skills: Python, AWS, JavaScript
7. Click "Generate"
8. Verify CV appears in list
9. Download PDF

### Automated E2E (Cypress)

Install Cypress:
```bash
npm install --save-dev cypress
```

Create test (cypress/e2e/cv-generation.cy.js):
```javascript
describe('CV Generation Flow', () => {
  it('should generate a CV from signup to download', () => {
    cy.visit('/');
    cy.contains('Sign Up').click();
    cy.get('input[name=email]').type('test@example.com');
    cy.get('input[name=password]').type('Password123!');
    cy.contains('Create Account').click();
    
    // Verify email step
    cy.contains('Verify Email');
    
    // Login
    cy.contains('Login').click();
    cy.get('input[name=email]').type('test@example.com');
    cy.get('input[name=password]').type('Password123!');
    cy.contains('Sign In').click();
    
    // Generate CV
    cy.contains('Generate CV').click();
    cy.get('input[name=name]').type('John Doe');
    cy.get('input[name=skills]').type('Python, AWS');
    cy.contains('Generate').click();
    
    // Verify success
    cy.contains('CV Generated').should('be.visible');
    cy.get('a[href*=".pdf"]').should('exist');
  });
});
```

Run tests:
```bash
npx cypress run --config baseUrl=http://$ALB_DNS
```

## Infrastructure Testing

### Validate Terraform

Check for drift (resources match code):
```bash
cd terraform
terraform plan -var-file=terraform.tfvars
```

Expected: `No changes. Your infrastructure matches the configuration.`

### Validate IAM Policies

```bash
aws accessanalyzer validate-policy \
  --policy-document file://terraform/iam.tf
```

### Check CloudFormation Stack

```bash
aws cloudformation describe-stacks \
  --stack-name hojadevida-backend-dev \
  --query 'Stacks[0].{Status:StackStatus,Updated:LastUpdatedTime}'
```

### Monitor with CloudWatch

View ALB metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time 2026-04-13T00:00:00Z \
  --end-time 2026-04-14T00:00:00Z \
  --period 3600 \
  --statistics Average
```

## Load Testing

### Install k6

```bash
# macOS
brew install k6

# Or download from https://k6.io/docs/getting-started/installation/
```

### Create Load Test Script

Create `loadtest.js`:
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const TOKEN = __ENV.JWT_TOKEN;
const API = 'https://4iuqo7wvq1.execute-api.us-east-1.amazonaws.com/dev';

export let options = {
  vus: 10,        // 10 concurrent users
  duration: '30s' // 30 seconds
};

export default function () {
  let res = http.get(`${API}/cvs`, {
    headers: { Authorization: `Bearer ${TOKEN}` }
  });
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
```

### Run Load Test

```bash
# Get token first
TOKEN=$(aws cognito-idp initiate-auth \
  --client-id 1d1orrgr2fj0pccbiaghl996to \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=test@example.com,PASSWORD=TempPass123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

# Run test
JWT_TOKEN=$TOKEN k6 run loadtest.js
```

Results will show:
- Requests/sec
- Response times (min, max, avg, p95, p99)
- Error rates
- HTTP status distribution

## Cleanup Procedures

⚠️ **CRITICAL**: Follow this order exactly to avoid issues!

### Step 1: Delete Terraform Resources (5 min)

```bash
cd terraform

# Preview
terraform plan -destroy -var-file=terraform.tfvars

# Delete
terraform destroy -var-file=terraform.tfvars -auto-approve

# Verify
terraform plan -var-file=terraform.tfvars
# Should show: "No changes."
```

This removes:
- ECS cluster, task definitions, services
- ALB, target groups
- VPC, subnets, security groups, NAT gateways
- CloudWatch logs and alarms
- IAM roles

### Step 2: Delete SAM Backend Stack (2 min)

```bash
aws cloudformation delete-stack --stack-name hojadevida-backend-dev

# Wait for completion
aws cloudformation wait stack-delete-complete --stack-name hojadevida-backend-dev

# Verify
aws cloudformation describe-stacks --stack-name hojadevida-backend-dev
# Should show: ValidationError (stack doesn't exist)
```

This removes:
- Lambda functions
- API Gateway HTTP API
- Cognito User Pool & Client
- DynamoDB table
- S3 bucket
- IAM execution roles

### Step 3: KEEP CloudFormation Account Setup ⚠️

**DO NOT DELETE** `hojadevida-account-setup`

This stack contains shared, reusable resources:
- GitHub OIDC Provider (for CI/CD)
- ECR Repository
- Terraform state S3 buckets (contains ALL history)
- DynamoDB lock tables (for Terraform locking)
- SAM artifact buckets

If deleted, you lose:
- All ability to redeploy
- Complete Terraform change history
- GitHub Actions AWS access

### Step 4: Check for Orphaned Resources

```bash
# S3 buckets
aws s3api list-buckets --query \
  'Buckets[?contains(Name, `hojadevida`)].Name'

# CloudWatch logs
aws logs describe-log-groups --query \
  'logGroups[?contains(logGroupName, `hojadevida`)].logGroupName'

# EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=hojadevida" \
  --query 'Reservations[].Instances[].InstanceId'
```

### Step 5: (Optional) Delete Account Setup

Only if you're completely done and never plan to redeploy:

```bash
aws cloudformation delete-stack --stack-name hojadevida-account-setup

aws cloudformation wait stack-delete-complete --stack-name hojadevida-account-setup
```

⚠️ **WARNING**: This is irreversible!

## Cost Tracking

Check costs before cleanup:

```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-04-13 \
  --granularity DAILY \
  --metrics BlendedCost
```

Estimated monthly costs (dev environment):
- Lambda: $0.20 (with free tier)
- API Gateway: $0.35 per million requests
- Cognito: $0 (free tier up to 50k users)
- DynamoDB: $1.25 (on-demand)
- S3: $0.023/GB
- NAT Gateway: $32/month
- ALB: $16.20/month
- **Total**: ~$50-60/month

## Quick Reference

### Resource Locations
```
Backend API:      https://4iuqo7wvq1.execute-api.us-east-1.amazonaws.com/dev
Cognito Pool:     us-east-1_7pA4zpLch
Cognito Client:   1d1orrgr2fj0pccbiaghl996to
DynamoDB Table:   hojadevida-cvs-dev
S3 Bucket:        hojadevida-cvs-871696174477-dev
Terraform State:  s3://hojadevida-terraform-state-871696174477-dev
AWS Account:      871696174477
Region:           us-east-1
```

### Test Credentials
```
Email:    test-user-1776133795@example.com
Password: TestPassword123!
```

### Commands Cheatsheet

```bash
# Deploy changes
git push origin main  # GitHub Actions handles deployment

# Check deployment status
terraform plan -var-file=terraform.tfvars

# Test API
TOKEN=$(aws cognito-idp initiate-auth \
  --client-id 1d1orrgr2fj0pccbiaghl996to \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=test@example.com,PASSWORD=TestPassword123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

curl -X GET https://4iuqo7wvq1.execute-api.us-east-1.amazonaws.com/dev/cvs \
  -H "Authorization: Bearer $TOKEN"

# Cleanup
cd terraform && terraform destroy -auto-approve
aws cloudformation delete-stack --stack-name hojadevida-backend-dev
aws cloudformation wait stack-delete-complete --stack-name hojadevida-backend-dev

# Check costs
aws ce get-cost-and-usage --time-period Start=2026-04-01,End=2026-04-13 \
  --granularity DAILY --metrics BlendedCost
```

## Troubleshooting

### API returns 401 Unauthorized
- Verify JWT token: `echo $TOKEN | cut -d'.' -f2 | base64 -d | jq '.'`
- Check token expiration: `exp` claim should be in future
- Verify Authorization header format: `Authorization: Bearer <TOKEN>`

### Lambda function not executing
- Check CloudWatch logs: `/aws/lambda/hojadevida-*-dev`
- Verify IAM role has DynamoDB and S3 permissions
- Check if function is in VPC (has ENI?)

### DynamoDB or S3 access denied
- Verify Lambda execution role has correct policies
- Check S3 bucket is not blocked by ACL
- Verify DynamoDB table exists and is in correct region

### Frontend can't reach API
- Check ALB security group allows inbound on port 80/443
- Verify API Gateway CORS configuration
- Check if ALB health checks pass

---

**Last Updated**: April 13, 2026  
**Author**: Auto-generated testing & cleanup guide  
**Project**: hojadevida-izador
