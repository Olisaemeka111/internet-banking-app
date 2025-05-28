#!/bin/bash

# Script to manually update the ECS services to use the correct container names

echo "=== Updating ECS Services ==="

# Update the API Gateway service
echo "Updating API Gateway service..."
aws ecs update-service \
  --cluster dev-internet-banking-cluster \
  --service dev-internet-banking-api-gateway \
  --task-definition dev-internet-banking-api-gateway \
  --force-new-deployment \
  --region us-east-1

# Update the Service Registry service
echo "Updating Service Registry service..."
aws ecs update-service \
  --cluster dev-internet-banking-cluster \
  --service dev-internet-banking-service-registry \
  --task-definition dev-internet-banking-service-registry \
  --force-new-deployment \
  --region us-east-1

echo "Services updated. It may take a few minutes for the changes to take effect."
echo "Run ./monitor_services.sh to check the status of the services."
