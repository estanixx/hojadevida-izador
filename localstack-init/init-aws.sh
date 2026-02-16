#!/bin/bash
echo "Initializing LocalStack Infrastructure..."

# 1. Crear el bucket para el código (Artifacts Bucket)
# Este bucket es técnico, solo para guardar los ZIPS de tus Lambdas
awslocal s3 mb s3://deployment-bucket

# 2. Movernos a la carpeta donde está el código
cd /etc/localstack/init/ready.d/backend

# 3. EL PASO QUE FALTABA: PACKAGE
# Esto toma tu carpeta 'src/', la zipea, la sube al bucket y crea un nuevo archivo 'packaged.yaml'
echo "Packaging CloudFormation template..."
awslocal cloudformation package \
  --template-file template.yaml \
  --s3-bucket deployment-bucket \
  --output-template-file packaged.yaml

# 4. AHORA SÍ: DEPLOY
# Usamos 'packaged.yaml' que ya tiene las referencias a S3 correctas
echo "Deploying CloudFormation stack..."
awslocal cloudformation deploy \
  --template-file packaged.yaml \
  --stack-name resume-stack \
  --capabilities CAPABILITY_IAM

echo "LocalStack Infrastructure Ready!"