#!/bin/bash

# Internet Banking Application Deployment Script
# This script automates the deployment of the Internet Banking application to AWS

set -e

echo "===== Internet Banking Application Deployment ====="
echo "Starting deployment process..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it before continuing."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install it before continuing."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install it before continuing."
    exit 1
fi

# Check if JDK 21 is installed
if ! command -v java &> /dev/null; then
    echo "WARNING: Java not found. Required for building microservices locally."
fi

# Function to ask for confirmation
confirm() {
    read -p "$1 (y/n): " choice
    case "$choice" in 
      y|Y ) return 0;;
      n|N ) return 1;;
      * ) echo "Invalid input. Please enter 'y' or 'n'."; confirm "$1";;
    esac
}

# Step 1: Configure AWS credentials
configure_aws() {
    echo "===== Step 1: Configuring AWS Credentials ====="
    
    # Ask for AWS credentials if not already configured
    if [ ! -f ~/.aws/credentials ]; then
        echo "AWS credentials not found. Let's configure them."
        aws configure
    else
        echo "AWS credentials found. Using existing configuration."
        echo "Current AWS profile:"
        aws sts get-caller-identity
        
        if ! confirm "Do you want to use these credentials?"; then
            aws configure
        fi
    fi
}

# Step 2: Setup Terraform backend
setup_terraform_backend() {
    echo "===== Step 2: Setting Up Terraform Backend ====="
    
    # Ask for S3 bucket name
    read -p "Enter S3 bucket name for Terraform state (default: internet-banking-terraform-state): " BUCKET_NAME
    BUCKET_NAME=${BUCKET_NAME:-internet-banking-terraform-state}
    
    # Ask for DynamoDB table name
    read -p "Enter DynamoDB table name for state locking (default: terraform-lock): " DYNAMODB_TABLE
    DYNAMODB_TABLE=${DYNAMODB_TABLE:-terraform-lock}
    
    # Create S3 bucket if it doesn't exist
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        echo "Creating S3 bucket: $BUCKET_NAME"
        aws s3 mb "s3://$BUCKET_NAME"
        aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    else
        echo "S3 bucket $BUCKET_NAME already exists."
    fi
    
    # Create DynamoDB table if it doesn't exist
    if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" >/dev/null 2>&1; then
        echo "Creating DynamoDB table: $DYNAMODB_TABLE"
        aws dynamodb create-table \
            --table-name "$DYNAMODB_TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST
    else
        echo "DynamoDB table $DYNAMODB_TABLE already exists."
    fi
    
    # Create backend.tfvars file
    echo "Creating Terraform backend configuration..."
    cat > terraform/backend.tfvars << EOF
bucket         = "${BUCKET_NAME}"
key            = "terraform.tfstate"
region         = "$(aws configure get region)"
encrypt        = true
dynamodb_table = "${DYNAMODB_TABLE}"
EOF
    
    echo "Terraform backend configuration created at terraform/backend.tfvars"
}

# Step 3: Configure Terraform variables
configure_terraform_vars() {
    echo "===== Step 3: Configuring Terraform Variables ====="
    
    # Get current AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    
    # Get current AWS region
    AWS_REGION=$(aws configure get region)
    
    echo "AWS Account ID: $AWS_ACCOUNT_ID"
    echo "AWS Region: $AWS_REGION"
    
    # Prompt for required variables
    read -p "Enter environment name (default: dev): " ENVIRONMENT
    ENVIRONMENT=${ENVIRONMENT:-dev}
    
    read -p "Enter VPC CIDR (default: 10.0.0.0/16): " VPC_CIDR
    VPC_CIDR=${VPC_CIDR:-10.0.0.0/16}
    
    read -p "Enter MySQL database name (default: banking_core_service): " MYSQL_DB_NAME
    MYSQL_DB_NAME=${MYSQL_DB_NAME:-banking_core_service}
    
    read -p "Enter MySQL username (default: admin): " MYSQL_USERNAME
    MYSQL_USERNAME=${MYSQL_USERNAME:-admin}
    
    read -sp "Enter MySQL password: " MYSQL_PASSWORD
    echo
    
    read -p "Enter PostgreSQL database name (default: keycloak): " POSTGRES_DB_NAME
    POSTGRES_DB_NAME=${POSTGRES_DB_NAME:-keycloak}
    
    read -p "Enter PostgreSQL username (default: admin): " POSTGRES_USERNAME
    POSTGRES_USERNAME=${POSTGRES_USERNAME:-admin}
    
    read -sp "Enter PostgreSQL password: " POSTGRES_PASSWORD
    echo
    
    read -p "Enter domain name (e.g., example.com): " DOMAIN_NAME
    
    # Create terraform.tfvars file
    echo "Creating Terraform variables file..."
    cat > terraform/terraform.tfvars << EOF
environment         = "${ENVIRONMENT}"
aws_region          = "${AWS_REGION}"
vpc_cidr            = "${VPC_CIDR}"
availability_zones  = ["${AWS_REGION}a", "${AWS_REGION}b"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
mysql_db_name       = "${MYSQL_DB_NAME}"
mysql_username      = "${MYSQL_USERNAME}"
mysql_password      = "${MYSQL_PASSWORD}"
postgres_db_name    = "${POSTGRES_DB_NAME}"
postgres_username   = "${POSTGRES_USERNAME}"
postgres_password   = "${POSTGRES_PASSWORD}"
domain_name         = "${DOMAIN_NAME}"
certificate_arn     = ""
waf_allowed_countries = ["US", "CA", "GB"]
aws_account_id      = "${AWS_ACCOUNT_ID}"
codestar_connection_arn = ""
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
    
    echo "Terraform variables file created at terraform/terraform.tfvars"
}

# Step 4: Apply security fixes
apply_security_fixes() {
    echo "===== Step 4: Applying Security Fixes ====="
    
    if [ ! -x "apply_security_fixes.sh" ]; then
        chmod +x apply_security_fixes.sh
    fi
    
    echo "Running security fixes script..."
    ./apply_security_fixes.sh
    
    echo "Security fixes applied. Please review the files in the security_fixes directory."
    if confirm "Do you want to manually copy the security fixes now?"; then
        echo "Please review and copy the files from the security_fixes directory to your terraform modules."
        read -p "Press Enter to continue when done..."
    fi
}

# Step 5: Provision infrastructure
provision_infrastructure() {
    echo "===== Step 5: Provisioning Infrastructure ====="
    
    cd terraform
    
    echo "Initializing Terraform..."
    terraform init -backend-config=backend.tfvars
    
    echo "Validating Terraform configuration..."
    terraform validate
    
    echo "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    if confirm "Do you want to apply the Terraform plan?"; then
        echo "Applying Terraform plan..."
        terraform apply tfplan
    else
        echo "Terraform apply skipped."
        return 1
    fi
    
    # Store outputs for later use
    echo "Storing Terraform outputs..."
    mkdir -p ../terraform-outputs
    terraform output -json > ../terraform-outputs/outputs.json
    
    cd ..
}

# Step 6: Build and push Docker images
build_and_push_images() {
    echo "===== Step 6: Building and Pushing Docker Images ====="
    
    # Check if we have the ECR repository URL from Terraform output
    ECR_URL=$(cat terraform-outputs/outputs.json | jq -r '.ecr_repository_url.value')
    
    if [ -z "$ECR_URL" ] || [ "$ECR_URL" == "null" ]; then
        echo "ECR repository URL not found in Terraform outputs."
        read -p "Enter ECR repository URL manually: " ECR_URL
    fi
    
    echo "Using ECR repository URL: $ECR_URL"
    
    # Log in to ECR
    echo "Logging in to ECR..."
    aws ecr get-login-password --region $(aws configure get region) | docker login --username AWS --password-stdin $ECR_URL
    
    # Check if we want to build the services locally
    if confirm "Do you want to build the microservices locally?"; then
        cd internet-banking-concept-microservices
        
        echo "Building microservices..."
        ./gradlew clean build -x test --parallel
        
        cd ..
    fi
    
    # Build and push Docker images
    cd internet-banking-concept-microservices
    
    SERVICES=("core-banking-service" "internet-banking-api-gateway" "internet-banking-service-registry" "internet-banking-config-server" "internet-banking-user-service" "internet-banking-fund-transfer-service" "internet-banking-utility-payment-service")
    
    for SERVICE in "${SERVICES[@]}"; do
        echo "Building and pushing Docker image for $SERVICE..."
        
        if [ -d "$SERVICE" ]; then
            cd $SERVICE
            
            echo "Building Docker image: $ECR_URL/$SERVICE:latest"
            docker build -t $ECR_URL/$SERVICE:latest .
            
            echo "Pushing Docker image to ECR..."
            docker push $ECR_URL/$SERVICE:latest
            
            cd ..
        else
            echo "Service directory $SERVICE not found. Skipping."
        fi
    done
    
    cd ..
}

# Step 7: Deploy to ECS
deploy_to_ecs() {
    echo "===== Step 7: Deploying to ECS ====="
    
    # Get ECR repository URL
    ECR_URL=$(cat terraform-outputs/outputs.json | jq -r '.ecr_repository_url.value')
    
    if [ -z "$ECR_URL" ] || [ "$ECR_URL" == "null" ]; then
        echo "ECR repository URL not found in Terraform outputs."
        read -p "Enter ECR repository URL manually: " ECR_URL
    fi
    
    # Get ECS cluster name
    ECS_CLUSTER=$(cat terraform-outputs/outputs.json | jq -r '.ecs_cluster_name.value')
    
    if [ -z "$ECS_CLUSTER" ] || [ "$ECS_CLUSTER" == "null" ]; then
        echo "ECS cluster name not found in Terraform outputs."
        read -p "Enter ECS cluster name manually: " ECS_CLUSTER
    fi
    
    echo "Using ECS cluster: $ECS_CLUSTER"
    
    # Update task definition templates
    echo "Updating task definition templates..."
    for TD_FILE in api-gateway-task-definition.json service-registry-task-definition.json; do
        if [ -f "$TD_FILE" ]; then
            echo "Updating $TD_FILE..."
            sed -i '' "s|156041437006.dkr.ecr.us-east-1.amazonaws.com|$ECR_URL|g" "$TD_FILE" || \
            sed -i "s|156041437006.dkr.ecr.us-east-1.amazonaws.com|$ECR_URL|g" "$TD_FILE"
        else
            echo "Task definition file $TD_FILE not found."
        fi
    done
    
    # Register and deploy task definitions
    echo "Registering and deploying task definitions..."
    
    SERVICES=("api-gateway" "service-registry" "config-server" "user-service" "fund-transfer-service" "utility-payment-service" "core-banking-service")
    
    for SERVICE in "${SERVICES[@]}"; do
        TD_FILE="${SERVICE}-task-definition.json"
        
        if [ -f "$TD_FILE" ]; then
            echo "Registering task definition from $TD_FILE..."
            aws ecs register-task-definition --cli-input-json file://"$TD_FILE"
            
            echo "Updating ECS service ${SERVICE}-service..."
            aws ecs update-service --cluster $ECS_CLUSTER --service ${SERVICE}-service --task-definition ${SERVICE}:latest --force-new-deployment
        else
            echo "Task definition file $TD_FILE not found. Skipping."
        fi
    done
}

# Step 8: Configure secrets
configure_secrets() {
    echo "===== Step 8: Configuring Secrets ====="
    
    # Get environment from Terraform outputs or use default
    ENVIRONMENT=$(cat terraform-outputs/outputs.json | jq -r '.environment.value' 2>/dev/null)
    ENVIRONMENT=${ENVIRONMENT:-dev}
    
    # Store MySQL credentials
    echo "Creating MySQL credentials secret..."
    aws secretsmanager create-secret \
        --name ${ENVIRONMENT}-mysql-credentials \
        --description "MySQL credentials for Banking Core Service" \
        --secret-string "{\"username\":\"$MYSQL_USERNAME\",\"password\":\"$MYSQL_PASSWORD\"}"
    
    # Store PostgreSQL credentials
    echo "Creating PostgreSQL credentials secret..."
    aws secretsmanager create-secret \
        --name ${ENVIRONMENT}-postgres-credentials \
        --description "PostgreSQL credentials for Keycloak" \
        --secret-string "{\"username\":\"$POSTGRES_USERNAME\",\"password\":\"$POSTGRES_PASSWORD\"}"
    
    # Generate and store encryption key
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    echo "Creating encryption key secret..."
    aws secretsmanager create-secret \
        --name ${ENVIRONMENT}-encryption-key \
        --description "Encryption key for services" \
        --secret-string "{\"key\":\"$ENCRYPTION_KEY\"}"
}

# Step 9: Configure DNS
configure_dns() {
    echo "===== Step 9: Configuring DNS ====="
    
    # Get ALB DNS name from Terraform outputs
    ALB_DNS=$(cat terraform-outputs/outputs.json | jq -r '.api_gateway_alb_dns.value')
    
    if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" == "null" ]; then
        echo "ALB DNS name not found in Terraform outputs."
        read -p "Enter ALB DNS name manually: " ALB_DNS
    fi
    
    # Get domain name from Terraform variables
    DOMAIN_NAME=$(grep -A 1 'domain_name' terraform/terraform.tfvars | tail -n 1 | cut -d '"' -f 2)
    
    if [ -z "$DOMAIN_NAME" ]; then
        echo "Domain name not found in Terraform variables."
        read -p "Enter domain name: " DOMAIN_NAME
    fi
    
    echo "Setting up DNS for domain: $DOMAIN_NAME"
    
    # List hosted zones
    echo "Available hosted zones:"
    aws route53 list-hosted-zones --query "HostedZones[].{Id:Id,Name:Name}" --output table
    
    read -p "Enter hosted zone ID: " HOSTED_ZONE_ID
    
    # Create A record
    echo "Creating A record for api.$DOMAIN_NAME pointing to $ALB_DNS..."
    aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch '{
            "Changes": [
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": "api.'$DOMAIN_NAME'",
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
}

# Step 10: Verify deployment
verify_deployment() {
    echo "===== Step 10: Verifying Deployment ====="
    
    # Get ECS cluster name
    ECS_CLUSTER=$(cat terraform-outputs/outputs.json | jq -r '.ecs_cluster_name.value')
    
    if [ -z "$ECS_CLUSTER" ] || [ "$ECS_CLUSTER" == "null" ]; then
        echo "ECS cluster name not found in Terraform outputs."
        read -p "Enter ECS cluster name manually: " ECS_CLUSTER
    fi
    
    # List ECS services
    echo "Listing ECS services in cluster $ECS_CLUSTER..."
    aws ecs list-services --cluster $ECS_CLUSTER
    
    # Get domain name from Terraform variables
    DOMAIN_NAME=$(grep -A 1 'domain_name' terraform/terraform.tfvars | tail -n 1 | cut -d '"' -f 2)
    
    if [ -z "$DOMAIN_NAME" ]; then
        echo "Domain name not found in Terraform variables."
        read -p "Enter domain name: " DOMAIN_NAME
    fi
    
    # Test API endpoint
    echo "Testing API endpoint..."
    curl -v https://api.$DOMAIN_NAME/actuator/health
}

# Main execution
main() {
    if confirm "Do you want to configure AWS credentials?"; then
        configure_aws
    fi
    
    if confirm "Do you want to set up the Terraform backend?"; then
        setup_terraform_backend
    fi
    
    if confirm "Do you want to configure Terraform variables?"; then
        configure_terraform_vars
    fi
    
    if confirm "Do you want to apply security fixes?"; then
        apply_security_fixes
    fi
    
    if confirm "Do you want to provision the infrastructure?"; then
        provision_infrastructure
    fi
    
    if confirm "Do you want to build and push Docker images?"; then
        build_and_push_images
    fi
    
    if confirm "Do you want to deploy to ECS?"; then
        deploy_to_ecs
    fi
    
    if confirm "Do you want to configure secrets in AWS Secrets Manager?"; then
        configure_secrets
    fi
    
    if confirm "Do you want to configure DNS?"; then
        configure_dns
    fi
    
    if confirm "Do you want to verify the deployment?"; then
        verify_deployment
    fi
    
    echo "===== Deployment Complete ====="
    echo "Thank you for using the Internet Banking Application Deployment Script."
}

# Execute main function
main 