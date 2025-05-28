#!/bin/bash

# Script to monitor the status of the Internet Banking services

echo "=== Monitoring Internet Banking Services ==="
echo "Current time: $(date)"
echo ""

# Check pipeline statuses
echo "=== Pipeline Statuses ==="
echo "Config Server Pipeline:"
aws codepipeline get-pipeline-state --name dev-internet-banking-config-server-pipeline --region us-east-1 | grep -A 5 "status"

echo "API Gateway Pipeline:"
aws codepipeline get-pipeline-state --name dev-internet-banking-api-gateway-pipeline --region us-east-1 | grep -A 5 "status"

echo "Service Registry Pipeline:"
aws codepipeline get-pipeline-state --name dev-internet-banking-service-registry-pipeline --region us-east-1 | grep -A 5 "status"
echo ""

# Check ECS service statuses
echo "=== ECS Service Statuses ==="
echo "Config Server Service:"
aws ecs describe-services --cluster dev-internet-banking-cluster --services dev-internet-banking-config-server --region us-east-1 | grep -A 5 "runningCount"

echo "API Gateway Service:"
aws ecs describe-services --cluster dev-internet-banking-cluster --services dev-internet-banking-api-gateway --region us-east-1 | grep -A 5 "runningCount"

echo "Service Registry Service:"
aws ecs describe-services --cluster dev-internet-banking-cluster --services dev-internet-banking-service-registry --region us-east-1 | grep -A 5 "runningCount"
echo ""

# Check target group health
echo "=== Target Group Health ==="
echo "API Gateway Target Group:"
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:us-east-1:156041437006:targetgroup/dev-api-gateway-tg/4ff71b24f8e04c4b --region us-east-1

echo ""
echo "=== Application URL ==="
echo "https://dev-public-alb-16320014.us-east-1.elb.amazonaws.com"
echo ""

echo "To check if the application is accessible, run:"
echo "curl -I https://dev-public-alb-16320014.us-east-1.elb.amazonaws.com"
echo ""

echo "Monitoring complete. Run this script again to get updated status."
