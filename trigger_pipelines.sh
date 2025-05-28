#!/bin/bash

# Script to trigger the pipelines for the API Gateway and Service Registry services

echo "Applying Terraform changes..."
cd /Users/olisa/Desktop/Internet\ banking\ \ app/terraform
terraform apply -auto-approve

echo "Triggering API Gateway pipeline..."
aws codepipeline start-pipeline-execution \
  --name dev-internet-banking-api-gateway-pipeline \
  --region us-east-1

echo "Triggering Service Registry pipeline..."
aws codepipeline start-pipeline-execution \
  --name dev-internet-banking-service-registry-pipeline \
  --region us-east-1

echo "Pipelines triggered. Monitoring status..."
echo "You can check the status of the pipelines in the AWS Console or by running:"
echo "aws codepipeline get-pipeline-state --name dev-internet-banking-api-gateway-pipeline --region us-east-1"
echo "aws codepipeline get-pipeline-state --name dev-internet-banking-service-registry-pipeline --region us-east-1"
