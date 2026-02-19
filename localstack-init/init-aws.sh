#!/bin/bash
set -e # Stop on error
rm -f /project/localstack-init/api-id.txt
echo "🚀 Initializing LocalStack Infrastructure..."

# 0. Setup Environment
PROJECT_ROOT="/project" # Matches the mount above
BUCKET_NAME="deployment-bucket"

# 1. Create S3 Buckets (Required for CloudFormation)
echo "📦 Creating Buckets..."
awslocal s3 mb s3://$BUCKET_NAME || true
awslocal s3 mb s3://resume-bucket-local || true

# 2. Deploy Networking (Layer 0)
# Note: In LocalStack Free, this creates mock resources.
echo "🌐 Deploying Networking Stack..."
awslocal cloudformation deploy \
  --template-file $PROJECT_ROOT/infrastructure/networking.yaml \
  --stack-name resume-networking

# 3. Deploy Backend (Layer 1)
echo "⚙️  Deploying Backend Stack..."

# We must package first to upload the Lambda code zip
awslocal cloudformation package \
  --template-file $PROJECT_ROOT/infrastructure/backend-service.yaml \
  --s3-bucket $BUCKET_NAME \
  --output-template-file /tmp/backend-packaged.yaml

awslocal cloudformation deploy \
  --template-file /tmp/backend-packaged.yaml \
  --stack-name resume-backend \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides Environment=local

echo "✅ Infrastructure Ready! (Frontend runs via docker-compose)"


# 3. EXTRACT ID AND SHARE IT
echo "🔍 Fetching API Gateway ID..."
API_ID=$(awslocal apigateway get-rest-apis --query "items[0].id" --output text)

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
  echo "❌ Error: Could not find API ID"
  exit 1
fi

echo "✅ API ID: $API_ID"

# Write the ID to a file in the shared folder
echo "$API_ID" > /project/localstack-init/api-id.tmp
mv /project/localstack-init/api-id.tmp /project/localstack-init/api-id.txt
chmod 644 /project/localstack-init/api-id.txt
echo "scriptexecutiondone" # Marker for logs