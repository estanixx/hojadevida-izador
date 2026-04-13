# hojadevida-izador Backend - AWS SAM

This backend uses **AWS SAM (Serverless Application Model)** to define, build, and deploy Lambda functions, API Gateway, Cognito, DynamoDB, and S3 resources.

## Architecture

```
┌─────────────────┐
│  Frontend (ECS) │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  API Gateway (HTTP API)         │
│  - /cvs (GET)                   │
│  - /cvs/generate (POST)         │
└────────┬────────────────────────┘
         │
         ├──────────────────────┬──────────────────────┐
         ▼                      ▼                      ▼
    ┌────────────┐      ┌────────────────┐     ┌──────────────┐
    │ ListCvs    │      │ GenerateCv     │     │ Cognito      │
    │ Lambda     │      │ Lambda         │     │ (JWT Auth)   │
    └────┬───────┘      └────┬───────────┘     └──────────────┘
         │                   │
         ├───────────────────┼─────────────────┐
         ▼                   ▼                 ▼
    ┌─────────┐      ┌──────────┐      ┌────────────┐
    │ DynamoDB│      │ Bedrock  │      │ S3 Bucket  │
    │ (CVs)   │      │ (Claude) │      │ (PDF Files)│
    └─────────┘      └──────────┘      └────────────┘
```

## File Structure

```
backend/
├── template.yaml                # SAM template (infrastructure-as-code)
├── samconfig.toml              # SAM configuration
├── package.json                # Node.js dependencies
├── .gitignore                  # Git ignore rules
│
├── src/                        # Lambda function source code
│   ├── shared.js              # Shared utilities and clients
│   ├── list_cvs/
│   │   └── index.js           # GET /cvs handler
│   └── generate_cv/
│       └── index.js           # POST /cvs/generate handler
│
└── [deprecated]
    ├── handler.js             # Old single-file approach (to be removed)
    └── serverless.yaml        # Old Serverless Framework config (to be removed)
```

## Prerequisites

- Node.js 20.x
- AWS CLI v2
- AWS SAM CLI (`pip install aws-sam-cli` or `brew install aws-sam-cli`)
- AWS credentials configured (via OIDC or IAM keys)

## Local Development

### Build

```bash
cd backend
sam build
```

### Deploy

**Development environment:**
```bash
sam deploy --config-env dev
```

**Production environment:**
```bash
sam deploy --config-env prod
```

Or manually specify all parameters:
```bash
sam deploy \
  --stack-name hojadevida-backend-dev \
  --parameter-overrides Environment=dev \
  --region us-east-1 \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --no-confirm-changeset
```

### Local Testing

Start SAM local API gateway:
```bash
sam local start-api
```

Then test with curl:
```bash
curl -X GET http://localhost:3000/cvs \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

## GitHub Actions Deployment

The workflow automatically deploys on:
- **Push to `main`** → Deploys to dev environment
- **Push to `prod`** → Deploys to prod environment

The workflow:
1. Checks out code
2. Builds backend with `sam build`
3. Deploys with `sam deploy` (creates or updates CloudFormation stack)
4. Retrieves outputs from the stack

## Environment Variables

Each Lambda function gets these environment variables automatically:
- `CVS_TABLE` - DynamoDB table name
- `CVS_BUCKET` - S3 bucket name
- `ENVIRONMENT` - Deployment environment (dev or prod)

Add more in `template.yaml` under `Globals.Function.Environment.Variables`.

## Monitoring and Logs

CloudWatch logs are automatically created for each function:
```bash
# View logs for a specific function
aws logs tail /aws/lambda/hojadevida-list-cvs-dev --follow

# View logs for all backend functions
aws logs tail /aws/lambda/hojadevida-* --follow
```

## Adding New Functions

1. Create a new directory in `src/`:
   ```bash
   mkdir src/my_function
   cd src/my_function
   touch index.js
   ```

2. Create the handler:
   ```javascript
   const { response, getUserId } = require('../shared');

   exports.handler = async (event) => {
     const userId = getUserId(event);
     if (!userId) {
       return response(401, { message: 'Unauthorized' });
     }

     // Your logic here
     return response(200, { message: 'Success' });
   };
   ```

3. Add to `template.yaml` under `Resources`:
   ```yaml
   MyNewFunction:
     Type: AWS::Serverless::Function
     Properties:
       FunctionName: !Sub 'hojadevida-my-function-${Environment}'
       CodeUri: src/my_function/
       Handler: index.handler
       Events:
         GetEndpoint:
           Type: HttpApi
           Properties:
             ApiId: !Ref HttpApi
             Path: /my-endpoint
             Method: GET
             Auth:
               Authorizer: CognitoAuthorizer
   ```

4. Add output if needed:
   ```yaml
   Outputs:
     MyNewFunctionArn:
       Value: !GetAtt MyNewFunction.Arn
       Export:
         Name: !Sub 'Hojadevida-MyNewFunction-${Environment}'
   ```

5. Deploy:
   ```bash
   sam deploy --config-env dev
   ```

## Shared Utilities

All functions can import helpers from `src/shared.js`:

```javascript
const {
  response,              // Format HTTP responses
  getUserId,            // Extract userId from JWT
  parseJson,            // Safe JSON parsing
  docClient,            // DynamoDB client
  s3Client,             // S3 client
  bedrockClient,        // Bedrock runtime client
  TABLE_NAME,           // DynamoDB table name
  BUCKET_NAME,          // S3 bucket name
  HAIKU_MODEL_ID,       // Bedrock model ID
  extractResumeJson,    // Parse Bedrock response
  buildResumePrompt,    // Build prompt for Bedrock
  renderPseudoPdfContent, // Render PDF content
  buildSignedUrl,       // Generate S3 presigned URL
} = require('../shared');
```

## CloudFormation Stack Outputs

After deployment, get outputs with:

```bash
aws cloudformation describe-stacks \
  --stack-name hojadevida-backend-dev \
  --query 'Stacks[0].Outputs' \
  --region us-east-1
```

Example outputs:
```
HttpApiEndpoint           https://abc123.execute-api.us-east-1.amazonaws.com/dev
ListCvsFunctionArn        arn:aws:lambda:us-east-1:871696174477:function:hojadevida-list-cvs-dev
GenerateCvFunctionArn     arn:aws:lambda:us-east-1:871696174477:function:hojadevida-generate-cv-dev
CvsDynamoDbTableName      hojadevida-cvs-dev
CvsS3BucketName           hojadevida-cvs-871696174477-dev
CognitoUserPoolId         us-east-1_ABC123XYZ
CognitoUserPoolClientId   abc123def456ghi789jkl012
CognitoUserPoolArn        arn:aws:cognito-idp:us-east-1:871696174477:userpool/us-east-1_ABC123XYZ
```

## Troubleshooting

### SAM build fails

Make sure Docker is running (SAM uses containers by default):
```bash
docker --version  # Should return a version
```

Or build without containers:
```bash
sam build --no-use-container
```

### Deployment fails with "AlreadyExists"

The Lambda function or API Gateway resource might already exist. Delete the old stack:
```bash
aws cloudformation delete-stack --stack-name hojadevida-backend-dev
```

Then redeploy:
```bash
sam deploy --config-env dev
```

### "Access Denied" errors

Make sure the GitHub OIDC role has permissions. Verify with:
```bash
aws iam get-role --role-name GitHubOIDCRole
aws iam list-attached-role-policies --role-name GitHubOIDCRole
```

### Logs not showing up

Wait 30-60 seconds after deployment for logs to start appearing:
```bash
aws logs describe-log-groups --query 'logGroups[].logGroupName' | grep hojadevida
```

## Migration from Serverless Framework

The old `serverless.yaml` and `handler.js` files are kept for reference but should be deleted once SAM is fully deployed:

- ✅ `template.yaml` - New SAM template
- ✅ `src/` - New function structure
- ✅ `samconfig.toml` - New configuration
- ❌ `serverless.yaml` - Deprecated (remove after testing)
- ❌ `handler.js` - Deprecated (remove after testing)

## Next Steps

1. **Local testing**: Run `sam local start-api` and test endpoints
2. **Push to main branch**: Trigger dev deployment
3. **Verify outputs**: Check CloudWatch logs and function metrics
4. **Update frontend**: Use the API endpoint from SAM outputs
5. **Push to prod**: Merge to prod branch for production deployment

---

For more details, see [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/).
