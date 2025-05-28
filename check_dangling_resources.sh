#!/bin/bash

# Script to check for any dangling resources related to the Internet Banking application
# This script will scan for resources that might have been missed in previous cleanup efforts

set -e  # Exit on error

AWS_REGION="us-east-1"

echo "Checking for dangling resources related to Internet Banking..."
echo "=============================================================="

# Check for S3 buckets with versioning
echo "Checking for S3 buckets with versioning..."
for bucket in dev-internet-banking-artifacts internet-banking-terraform-state-dev; do
  echo "Checking bucket $bucket..."
  if aws s3api head-bucket --bucket $bucket 2>/dev/null; then
    echo "Bucket $bucket still exists. Cleaning up all versions..."
    # Delete all versions
    aws s3api delete-objects --bucket $bucket --delete "$(aws s3api list-object-versions --bucket $bucket --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{"Objects":[]}')"
    # Delete all delete markers
    aws s3api delete-objects --bucket $bucket --delete "$(aws s3api list-object-versions --bucket $bucket --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{"Objects":[]}')"
    # Delete the bucket
    aws s3 rb s3://$bucket --force
    echo "Bucket $bucket deleted."
  else
    echo "Bucket $bucket does not exist."
  fi
done

# Check for AWS Cloud Map namespace
echo "Checking for AWS Cloud Map namespace..."
NAMESPACE_ID="ns-cv62nq7anw7hqoez"
if aws servicediscovery get-namespace --id $NAMESPACE_ID 2>/dev/null; then
  echo "AWS Cloud Map namespace $NAMESPACE_ID exists. Attempting to delete..."
  
  # First, list and delete all services in the namespace
  SERVICES=$(aws servicediscovery list-services --filters "Name=NAMESPACE_ID,Values=$NAMESPACE_ID" --query "Services[].Id" --output text)
  for service_id in $SERVICES; do
    echo "Deleting service $service_id..."
    # First deregister all instances
    INSTANCES=$(aws servicediscovery list-instances --service-id $service_id --query "Instances[].Id" --output text)
    for instance_id in $INSTANCES; do
      echo "Deregistering instance $instance_id..."
      aws servicediscovery deregister-instance --service-id $service_id --instance-id $instance_id
    done
    # Now delete the service
    aws servicediscovery delete-service --id $service_id
    echo "Service $service_id deleted."
  done
  
  # Now delete the namespace
  aws servicediscovery delete-namespace --id $NAMESPACE_ID
  echo "AWS Cloud Map namespace $NAMESPACE_ID deleted."
else
  echo "AWS Cloud Map namespace $NAMESPACE_ID does not exist."
fi

# Check for any remaining CloudWatch log groups
echo "Checking for CloudWatch log groups..."
LOG_GROUPS=$(aws logs describe-log-groups --log-group-name-prefix "/ecs/dev/internet-banking" --query "logGroups[].logGroupName" --output text --region $AWS_REGION)
if [ -n "$LOG_GROUPS" ]; then
  echo "Found CloudWatch log groups:"
  echo "$LOG_GROUPS"
  for log_group in $LOG_GROUPS; do
    echo "Deleting log group $log_group..."
    aws logs delete-log-group --log-group-name "$log_group" --region $AWS_REGION
    echo "Log group $log_group deleted."
  done
else
  echo "No CloudWatch log groups found."
fi

# Check for any remaining IAM roles
echo "Checking for IAM roles..."
IAM_ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, 'internet-banking') || contains(RoleName, 'dev-ecs')].RoleName" --output text)
if [ -n "$IAM_ROLES" ]; then
  echo "Found IAM roles:"
  echo "$IAM_ROLES"
  for role in $IAM_ROLES; do
    echo "Checking role $role..."
    # First detach all policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text)
    for policy in $ATTACHED_POLICIES; do
      echo "Detaching policy $policy from role $role..."
      aws iam detach-role-policy --role-name $role --policy-arn $policy
    done
    
    # Delete any inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name $role --query "PolicyNames" --output text)
    for policy in $INLINE_POLICIES; do
      echo "Deleting inline policy $policy from role $role..."
      aws iam delete-role-policy --role-name $role --policy-name $policy
    done
    
    # Now delete the role
    echo "Deleting role $role..."
    aws iam delete-role --role-name $role || echo "Failed to delete role $role"
  done
else
  echo "No IAM roles found."
fi

# Check for any remaining IAM policies
echo "Checking for IAM policies..."
IAM_POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'internet-banking') || contains(PolicyName, 'dev-ecs')].Arn" --output text)
if [ -n "$IAM_POLICIES" ]; then
  echo "Found IAM policies:"
  echo "$IAM_POLICIES"
  for policy in $IAM_POLICIES; do
    echo "Deleting policy $policy..."
    aws iam delete-policy --policy-arn $policy || echo "Failed to delete policy $policy"
  done
else
  echo "No IAM policies found."
fi

# Check for any remaining KMS keys
echo "Checking for KMS keys..."
KMS_KEYS=$(aws kms list-keys --query "Keys[].KeyId" --output text --region $AWS_REGION)
for key_id in $KMS_KEYS; do
  # Get key description to check if it's related to Internet Banking
  KEY_DESC=$(aws kms describe-key --key-id $key_id --query "KeyMetadata.Description" --output text --region $AWS_REGION)
  if [[ "$KEY_DESC" == *"internet-banking"* || "$KEY_DESC" == *"Internet Banking"* ]]; then
    echo "Found KMS key related to Internet Banking: $key_id"
    echo "Scheduling key deletion..."
    aws kms schedule-key-deletion --key-id $key_id --pending-window-in-days 7 --region $AWS_REGION || echo "Failed to schedule deletion for key $key_id"
  fi
done

# Check for any remaining CodeBuild projects
echo "Checking for CodeBuild projects..."
CODEBUILD_PROJECTS=$(aws codebuild list-projects --query "projects[?contains(@, 'internet-banking')]" --output text --region $AWS_REGION)
if [ -n "$CODEBUILD_PROJECTS" ]; then
  echo "Found CodeBuild projects:"
  echo "$CODEBUILD_PROJECTS"
  for project in $CODEBUILD_PROJECTS; do
    echo "Deleting CodeBuild project $project..."
    aws codebuild delete-project --name $project --region $AWS_REGION
    echo "CodeBuild project $project deleted."
  done
else
  echo "No CodeBuild projects found."
fi

# Check for any remaining CodePipeline pipelines
echo "Checking for CodePipeline pipelines..."
CODEPIPELINE_PIPELINES=$(aws codepipeline list-pipelines --query "pipelines[?contains(name, 'internet-banking')].name" --output text --region $AWS_REGION)
if [ -n "$CODEPIPELINE_PIPELINES" ]; then
  echo "Found CodePipeline pipelines:"
  echo "$CODEPIPELINE_PIPELINES"
  for pipeline in $CODEPIPELINE_PIPELINES; do
    echo "Deleting CodePipeline pipeline $pipeline..."
    aws codepipeline delete-pipeline --name $pipeline --region $AWS_REGION
    echo "CodePipeline pipeline $pipeline deleted."
  done
else
  echo "No CodePipeline pipelines found."
fi

echo "=============================================================="
echo "Dangling resource check and cleanup completed."
echo "Some resources may still be in the process of deletion."
echo "Please check the AWS Management Console to confirm all resources have been removed."
