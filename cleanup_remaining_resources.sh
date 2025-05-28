#!/bin/bash

# Script to clean up remaining AWS resources related to the Internet Banking application
# This script will remove all identified resources that could incur charges

set -e  # Exit on error

AWS_REGION="us-east-1"

echo "Starting cleanup of remaining Internet Banking resources..."

# 1. Terminate EC2 instances
echo "Terminating EC2 instances..."
aws ec2 terminate-instances --instance-ids i-01a2208e10d69fd0f i-08ba1cce5ff2980ec --region $AWS_REGION
echo "EC2 instances termination initiated."

# 2. Wait for instances to terminate
echo "Waiting for instances to terminate..."
aws ec2 wait instance-terminated --instance-ids i-01a2208e10d69fd0f i-08ba1cce5ff2980ec --region $AWS_REGION
echo "EC2 instances terminated."

# 3. Delete EBS volumes
echo "Deleting EBS volumes..."
for volume_id in vol-0cf12bec5c5b0c91c vol-0570b26afaa5739fe vol-0c89531cd05a9e0a7 vol-0f435616687d749b2; do
  echo "Deleting volume $volume_id..."
  aws ec2 delete-volume --volume-id $volume_id --region $AWS_REGION || echo "Failed to delete volume $volume_id"
done
echo "Available EBS volumes deleted."

# 4. Delete Lambda function
echo "Deleting Lambda function..."
aws lambda delete-function --function-name dev-internet-banking-security-notification --region $AWS_REGION
echo "Lambda function deleted."

# 5. Delete S3 buckets (first empty them)
echo "Emptying and deleting S3 buckets..."
for bucket in dev-internet-banking-artifacts dev-internet-banking-security-reports internet-banking-terraform-state-dev; do
  echo "Emptying bucket $bucket..."
  aws s3 rm s3://$bucket --recursive || echo "Failed to empty bucket $bucket"
  
  echo "Deleting bucket $bucket..."
  aws s3 rb s3://$bucket --force || echo "Failed to delete bucket $bucket"
done
echo "S3 buckets deleted."

# 6. Delete Route53 hosted zones
echo "Deleting Route53 hosted zones..."
# First, we need to get the record sets and delete them
for zone_id in Z051120839V54WZFM66GR Z0232372E2YHFGXA0BU8; do
  echo "Getting record sets for zone $zone_id..."
  records=$(aws route53 list-resource-record-sets --hosted-zone-id $zone_id --region $AWS_REGION)
  
  # Create a change batch file to delete all non-SOA/NS records
  echo '{
    "Changes": [' > change-batch.json
  
  # Extract and format each record for deletion
  echo "$records" | jq -r '.ResourceRecordSets[] | select(.Type != "SOA" and .Type != "NS") | {
    "Action": "DELETE",
    "ResourceRecordSet": {
      "Name": .Name,
      "Type": .Type,
      "TTL": .TTL,
      "ResourceRecords": .ResourceRecords
    }
  }' | jq -s 'map(.)' | jq '.[0:-1] | map(. + ",")' | jq -r '.[]' >> change-batch.json
  
  # Add the last record without a comma
  echo "$records" | jq -r '.ResourceRecordSets[] | select(.Type != "SOA" and .Type != "NS") | {
    "Action": "DELETE",
    "ResourceRecordSet": {
      "Name": .Name,
      "Type": .Type,
      "TTL": .TTL,
      "ResourceRecords": .ResourceRecords
    }
  }' | jq -s 'map(.)' | jq '.[-1]' >> change-batch.json
  
  echo '  ]
}' >> change-batch.json
  
  # Apply the changes to delete the records
  echo "Deleting record sets for zone $zone_id..."
  aws route53 change-resource-record-sets --hosted-zone-id $zone_id --change-batch file://change-batch.json --region $AWS_REGION || echo "No records to delete or failed to delete records for zone $zone_id"
  
  # Now delete the hosted zone
  echo "Deleting hosted zone $zone_id..."
  aws route53 delete-hosted-zone --id $zone_id --region $AWS_REGION || echo "Failed to delete hosted zone $zone_id"
done
echo "Route53 hosted zones deleted."

# 7. Delete ECR repositories
echo "Deleting ECR repositories..."
for repo in zipkin keycloak core-banking-service; do
  echo "Deleting repository $repo..."
  aws ecr delete-repository --repository-name $repo --force --region $AWS_REGION || echo "Failed to delete repository $repo"
done
echo "ECR repositories deleted."

# 8. Delete DynamoDB tables related to Internet Banking
echo "Deleting DynamoDB tables..."
aws dynamodb delete-table --table-name terraform-lock-dev --region $AWS_REGION || echo "Failed to delete table terraform-lock-dev"
echo "DynamoDB tables deleted."

echo "Cleanup of remaining Internet Banking resources completed!"
echo "Note: Some resources may take time to fully delete. Check the AWS Management Console to confirm."
