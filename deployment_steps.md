# Internet Banking Application Deployment Guide

This guide provides step-by-step instructions to provision AWS infrastructure and deploy the Internet Banking microservices application.

## Prerequisites

1. AWS CLI installed and configured with appropriate permissions
2. Terraform installed (version 1.0.0 or later)
3. Docker and Docker Compose installed
4. Git client
5. JDK 21 installed for local builds (if needed)

## Step 1: Clone the Repository

```bash
git clone https://github.com/Olisaemeka111/internet-banking-app.git
cd internet-banking-app
```

## Step 2: Configure AWS Credentials and Terraform Backend

1. Set up AWS credentials:

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region (us-east-1), and output format (json)
```

2. Create an S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://internet-banking-terraform-state

# Enable versioning
aws s3api put-bucket-versioning --bucket internet-banking-terraform-state --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

3. Update the Terraform backend configuration:

```bash
# Edit terraform/backend.tfvars with your configuration
cat > terraform/backend.tfvars << EOF
bucket         = "internet-banking-terraform-state"
key            = "terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-lock"
EOF
```

## Step 3: Configure Terraform Variables

Create a terraform.tfvars file with your configuration:

```bash
# Edit terraform/terraform.tfvars with your configuration
cat > terraform/terraform.tfvars << EOF
environment         = "dev"
aws_region          = "us-east-1"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
mysql_db_name       = "banking_core_service"
mysql_username      = "admin"
mysql_password      = "REPLACE_WITH_SECURE_PASSWORD"
postgres_db_name    = "keycloak"
postgres_username   = "admin"
postgres_password   = "REPLACE_WITH_SECURE_PASSWORD"
domain_name         = "your-domain.com"
certificate_arn     = "arn:aws:acm:us-east-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID"
waf_allowed_countries = ["US", "CA", "GB"]
aws_account_id      = "YOUR_ACCOUNT_ID"
codestar_connection_arn = "arn:aws:codestar-connections:us-east-1:YOUR_ACCOUNT_ID:connection/YOUR_CONNECTION_ID"
repository_id       = "Olisaemeka111/internet-banking-app"
branch_name         = "main"
services = {
  "internet-banking-api-gateway" = {
    container_port = 8082
    host_port      = 8082
    cpu            = 512
    memory         = 1024
    desired_count  = 2
    requires_public_access = true
  },
  "internet-banking-service-registry" = {
    container_port = 8081
    host_port      = 8081
    cpu            = 512
    memory         = 1024
    desired_count  = 2
    requires_public_access = false
  },
  "internet-banking-config-server" = {
    container_port = 8090
    host_port      = 8090
    cpu            = 512
    memory         = 1024
    desired_count  = 2
    requires_public_access = false
  },
  "internet-banking-user-service" = {
    container_port = 8083
    host_port      = 8083
    cpu            = 512
    memory         = 1024
    desired_count  = 2
    requires_public_access = false
  },
  "internet-banking-fund-transfer-service" = {
    container_port = 8084
    host_port      = 8084
    cpu            = 512
    memory         = 1024
    desired_count  = 2
    requires_public_access = false
  },
  "internet-banking-utility-payment-service" = {
    container_port = 8085
    host_port      = 8085
    cpu            = 512
    memory         = 1024
    desired_count  = 2
    requires_public_access = false
  },
  "core-banking-service" = {
    container_port = 8092
    host_port      = 8092
    cpu            = 512
    memory         = 1024
    desired_count  = 2
    requires_public_access = false
  }
}
EOF
```

## Step 4: Apply Security Fixes to Infrastructure

Apply the security fixes to the Terraform configuration:

```bash
# Make the script executable
chmod +x apply_security_fixes.sh

# Run the script to generate security fixes
./apply_security_fixes.sh

# Review the changes in the security_fixes directory
# Apply the necessary changes to your terraform configuration
```

## Step 5: Provision the Infrastructure

Initialize and apply the Terraform configuration:

```bash
cd terraform

# Initialize Terraform with the backend configuration
terraform init -backend-config=backend.tfvars

# Validate the configuration
terraform validate

# Plan the infrastructure changes
terraform plan -out=tfplan

# Apply the infrastructure changes
terraform apply tfplan
```

## Step 6: Build and Push Docker Images

1. Build the microservices:

```bash
cd internet-banking-concept-microservices

# Build each service using Gradle
./gradlew clean build -x test

# Or build all services at once
./gradlew clean build -x test --parallel
```

2. Build and push Docker images:

```bash
# Get the ECR repository URL from Terraform output
ECR_URL=$(cd ../terraform && terraform output -raw ecr_repository_url)

# Log in to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Build and push each service
for SERVICE in core-banking-service internet-banking-api-gateway internet-banking-service-registry internet-banking-config-server internet-banking-user-service internet-banking-fund-transfer-service internet-banking-utility-payment-service; do
  cd $SERVICE
  docker build -t $ECR_URL/$SERVICE:latest .
  docker push $ECR_URL/$SERVICE:latest
  cd ..
done
```

## Step 7: Deploy the Application to ECS

Create task definition files for each service from the templates:

```bash
# Use existing task definition templates and update them with the correct ECR repository URLs
sed -i "s|156041437006.dkr.ecr.us-east-1.amazonaws.com|$ECR_URL|g" api-gateway-task-definition.json
sed -i "s|156041437006.dkr.ecr.us-east-1.amazonaws.com|$ECR_URL|g" service-registry-task-definition.json
# Repeat for other task definitions
```

Register and deploy the task definitions:

```bash
# Register task definitions
aws ecs register-task-definition --cli-input-json file://api-gateway-task-definition.json
aws ecs register-task-definition --cli-input-json file://service-registry-task-definition.json
# Repeat for other task definitions

# Update ECS services to use the latest task definitions
aws ecs update-service --cluster internet-banking-cluster --service api-gateway-service --task-definition api-gateway:latest --force-new-deployment
aws ecs update-service --cluster internet-banking-cluster --service service-registry-service --task-definition service-registry:latest --force-new-deployment
# Repeat for other services
```

## Step 8: Configure Secrets in AWS Secrets Manager

Create secrets for database credentials and API keys:

```bash
# Store MySQL credentials
aws secretsmanager create-secret \
  --name dev-mysql-credentials \
  --description "MySQL credentials for Banking Core Service" \
  --secret-string '{"username":"admin","password":"YOUR_PASSWORD"}'

# Store PostgreSQL credentials
aws secretsmanager create-secret \
  --name dev-postgres-credentials \
  --description "PostgreSQL credentials for Keycloak" \
  --secret-string '{"username":"admin","password":"YOUR_PASSWORD"}'

# Store encryption key
aws secretsmanager create-secret \
  --name dev-encryption-key \
  --description "Encryption key for services" \
  --secret-string '{"key":"YOUR_ENCRYPTION_KEY"}'
```

## Step 9: Configure DNS and SSL

Configure Route 53 for your domain:

```bash
# Get the ALB DNS name from Terraform output
ALB_DNS=$(cd terraform && terraform output -raw api_gateway_alb_dns)

# Create a Route 53 record set
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "api.your-domain.com",
          "Type": "A",
          "AliasTarget": {
            "HostedZoneId": "Z35SXDOTRQ7X7K",
            "DNSName": "'$ALB_DNS'",
            "EvaluateTargetHealth": true
          }
        }
      }
    ]
  }'
```

## Step 10: Verify the Deployment

1. Check if all ECS services are running:

```bash
aws ecs list-services --cluster internet-banking-cluster

# Check the status of each service
aws ecs describe-services --cluster internet-banking-cluster --services api-gateway-service service-registry-service
```

2. Check the CloudWatch logs for each service:

```bash
aws logs get-log-events --log-group-name /ecs/dev/dev-internet-banking-api-gateway --log-stream-name PREFIX/internet-banking-api-gateway/TASK_ID
```

3. Test the API endpoints:

```bash
# Test the API Gateway
curl -X GET https://api.your-domain.com/actuator/health
```

## Step 11: Configure Monitoring and Alerting

1. Set up CloudWatch dashboards:

```bash
aws cloudwatch put-dashboard --dashboard-name InternetBanking --dashboard-body file://monitoring/cloudwatch-dashboard.json
```

2. Configure CloudWatch alarms:

```bash
# CPU utilization alarm for API Gateway
aws cloudwatch put-metric-alarm \
  --alarm-name api-gateway-high-cpu \
  --alarm-description "High CPU utilization for API Gateway" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=ClusterName,Value=internet-banking-cluster" "Name=ServiceName,Value=api-gateway-service" \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:alerts
```

## Step 12: Enable CI/CD Pipeline

1. Create a GitHub connection in AWS CodeStar:

```bash
aws codestar-connections create-connection \
  --provider-type GitHub \
  --connection-name GitHub-InternetBanking
```

2. Follow the link provided to complete the GitHub authorization.

3. Create a CodePipeline for each service:

```bash
aws codepipeline create-pipeline --cli-input-json file://ci-cd/api-gateway-pipeline.json
# Repeat for other services
```

## Step 13: Implement Security Measures

1. Enable AWS WAF:

```bash
# Deploy the WAF configuration
cd terraform
terraform apply -target=module.internet_banking.module.waf
```

2. Configure AWS Config for compliance monitoring:

```bash
# Enable AWS Config
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=arn:aws:iam::YOUR_ACCOUNT_ID:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig \
  --recording-group allSupported=true,includeGlobalResources=true

# Start the configuration recorder
aws configservice start-configuration-recorder --configuration-recorder-name default
```

## Troubleshooting

1. **ECS Service Deployment Issues**:
   - Check CloudWatch logs for container startup errors
   - Verify security group rules allow necessary traffic
   - Check if ECS agent is running properly on instances

2. **Database Connection Issues**:
   - Verify security group rules allow traffic from ECS to RDS
   - Check credentials in Secrets Manager
   - Test connectivity from a bastion host

3. **API Gateway Issues**:
   - Check health of the underlying ECS service
   - Verify load balancer target group health
   - Check WAF rules aren't blocking legitimate traffic

## Maintenance and Updates

1. **Updating Microservices**:
   - Build new Docker images with updated code
   - Push to ECR with a new tag
   - Update the ECS service to use the new task definition

2. **Scaling**:
   - Adjust desired count in ECS services
   - Modify auto-scaling rules as needed
   - Consider upgrading instance types or Fargate configuration

3. **Backup and Recovery**:
   - RDS automated backups are enabled
   - Review and test restore procedures periodically
   - Consider cross-region replication for disaster recovery

## Security Best Practices

1. **Regular Auditing**:
   - Run the security scan regularly: `./scan-infrastructure.sh`
   - Review AWS Config findings
   - Conduct periodic penetration testing

2. **Secrets Rotation**:
   - Set up automatic rotation for database credentials
   - Rotate IAM access keys regularly
   - Update encryption keys periodically

3. **Updates and Patches**:
   - Keep container images updated with security patches
   - Update ECS/EC2 AMIs regularly
   - Apply RDS updates during maintenance windows 