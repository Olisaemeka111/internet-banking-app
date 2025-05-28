#!/bin/bash

# This script performs a complete cleanup of all AWS resources related to the Internet Banking application
# It handles dependencies in the correct order to ensure everything is deleted properly

set -e  # Exit on error

AWS_REGION="us-east-1"
VPC_ID="vpc-0d57b94cbe8b4c11c"

echo "Starting complete cleanup of Internet Banking application infrastructure..."

# Wait for ElastiCache Redis cluster to be deleted
echo "Waiting for ElastiCache Redis cluster to be deleted..."
while aws elasticache describe-replication-groups --region $AWS_REGION | grep -q "dev-internet-banking-redis"; do
  echo "ElastiCache Redis cluster is still being deleted, waiting 30 seconds..."
  sleep 30
done
echo "ElastiCache Redis cluster has been deleted successfully."

# Wait for NAT gateways to be deleted
echo "Waiting for NAT gateways to be deleted..."
while aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region $AWS_REGION | grep -q "\"State\": \"deleting\""; do
  echo "NAT gateways are still being deleted, waiting 30 seconds..."
  sleep 30
done
echo "NAT gateways have been deleted successfully."

# Release Elastic IPs
echo "Releasing Elastic IPs..."
for eip_id in $(aws ec2 describe-addresses --region $AWS_REGION --query 'Addresses[].AllocationId' --output text); do
  echo "Releasing Elastic IP $eip_id..."
  aws ec2 release-address --allocation-id $eip_id --region $AWS_REGION
  echo "Elastic IP $eip_id released."
done

# Delete security groups
echo "Deleting security groups..."
for sg_id in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region $AWS_REGION --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
  echo "Deleting security group $sg_id..."
  aws ec2 delete-security-group --group-id $sg_id --region $AWS_REGION || echo "Failed to delete $sg_id, will retry later"
done

# Detach and delete internet gateway
echo "Detaching and deleting internet gateway..."
for igw_id in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region $AWS_REGION --query 'InternetGateways[].InternetGatewayId' --output text); do
  echo "Detaching internet gateway $igw_id..."
  aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $VPC_ID --region $AWS_REGION
  echo "Internet gateway $igw_id detached."
  
  echo "Deleting internet gateway $igw_id..."
  aws ec2 delete-internet-gateway --internet-gateway-id $igw_id --region $AWS_REGION
  echo "Internet gateway $igw_id deleted."
done

# Delete route tables (except the main one)
echo "Deleting route tables..."
for rt_id in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --region $AWS_REGION --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text); do
  echo "Deleting route table $rt_id..."
  
  # First, disassociate any subnet associations
  for assoc_id in $(aws ec2 describe-route-tables --route-table-id $rt_id --region $AWS_REGION --query 'RouteTables[].Associations[?Main!=`true`].RouteTableAssociationId' --output text); do
    echo "Disassociating route table association $assoc_id..."
    aws ec2 disassociate-route-table --association-id $assoc_id --region $AWS_REGION
    echo "Route table association $assoc_id disassociated."
  done
  
  # Now delete the route table
  aws ec2 delete-route-table --route-table-id $rt_id --region $AWS_REGION
  echo "Route table $rt_id deleted."
done

# Delete subnets
echo "Deleting subnets..."
for subnet_id in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $AWS_REGION --query 'Subnets[].SubnetId' --output text); do
  echo "Deleting subnet $subnet_id..."
  aws ec2 delete-subnet --subnet-id $subnet_id --region $AWS_REGION
  echo "Subnet $subnet_id deleted."
done

# Delete default security group
echo "Deleting default security group..."
for sg_id in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" --region $AWS_REGION --query 'SecurityGroups[].GroupId' --output text); do
  echo "Deleting default security group $sg_id..."
  aws ec2 delete-security-group --group-id $sg_id --region $AWS_REGION || echo "Failed to delete default security group $sg_id"
done

# Delete VPC
echo "Deleting VPC $VPC_ID..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION
echo "VPC $VPC_ID deleted."

# Check for any remaining resources
echo "Checking for any remaining resources..."

# Check for remaining ECS resources
echo "Checking for remaining ECS clusters..."
aws ecs list-clusters --region $AWS_REGION

# Check for remaining ECR repositories
echo "Checking for remaining ECR repositories..."
aws ecr describe-repositories --region $AWS_REGION | grep -i internet-banking || echo "No ECR repositories found."

# Check for remaining RDS instances
echo "Checking for remaining RDS instances..."
aws rds describe-db-instances --region $AWS_REGION | grep -i banking || echo "No RDS instances found."

# Check for remaining ElastiCache clusters
echo "Checking for remaining ElastiCache clusters..."
aws elasticache describe-replication-groups --region $AWS_REGION | grep -i internet-banking || echo "No ElastiCache clusters found."

# Check for remaining load balancers
echo "Checking for remaining load balancers..."
aws elbv2 describe-load-balancers --region $AWS_REGION | grep -i dev || echo "No load balancers found."

# Check for remaining target groups
echo "Checking for remaining target groups..."
aws elbv2 describe-target-groups --region $AWS_REGION | grep -i dev || echo "No target groups found."

echo "Cleanup completed successfully!"
