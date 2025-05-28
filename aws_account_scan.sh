#!/bin/bash

# Comprehensive AWS account scan to detect any resources that might incur charges
# This script checks all major AWS services across all regions and provides cost estimates

# Allow specifying specific regions to scan (comma-separated)
SPECIFIC_REGIONS=${1:-""}

set -e  # Exit on error

# Define colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize cost variables
TOTAL_ESTIMATED_COST=0
# Instead of using associative arrays, we'll use a simple text file to track costs
SERVICE_COSTS_FILE=$(mktemp)
# Also save all found resources for the final report
RESOURCES_FOUND_FILE=$(mktemp)

# Get all enabled AWS regions or use specified regions
echo -e "${YELLOW}Getting list of enabled AWS regions...${NC}"
if [ -z "$SPECIFIC_REGIONS" ]; then
    # Try to get all regions, but fall back to a default list if there's an error
    REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text 2>/dev/null || echo "us-east-1 us-east-2 us-west-1 us-west-2")
else
    # Use the specified regions
    REGIONS=$(echo $SPECIFIC_REGIONS | tr ',' ' ')
    echo -e "${YELLOW}Using specified regions: ${REGIONS}${NC}"
fi

echo -e "${YELLOW}Starting comprehensive AWS account scan...${NC}"
echo "==============================================="
echo "This scan will check for resources across all AWS regions and estimate costs."
echo "==============================================="

# Function to estimate costs for various resources
estimate_cost() {
    local service=$1
    local resource_type=$2
    local count=$3
    local details=$4
    local cost=0

    case $service in
        EC2)
            # Extract instance type from details
            instance_type=$(echo "$details" | awk '{print $3}')
            case $instance_type in
                t2.micro|t3.micro) cost=$(echo "$count * 8.50" | bc) ;; # ~$8.50/month for t2/t3.micro
                t2.small|t3.small) cost=$(echo "$count * 17" | bc) ;; # ~$17/month
                t2.medium|t3.medium) cost=$(echo "$count * 34" | bc) ;; # ~$34/month
                m5.large) cost=$(echo "$count * 80" | bc) ;; # ~$80/month
                *) cost=$(echo "$count * 50" | bc) ;; # Default estimate
            esac
            ;;
        EBS)
            # Assuming average EBS volume is 100GB at $0.10/GB/month
            size=$(echo "$details" | awk '{sum+=$2} END {print sum}')
            cost=$(echo "scale=2; $size * 0.10" | bc)
            ;;
        RDS)
            cost=$(echo "$count * 50" | bc) # Rough estimate, varies greatly by instance type
            ;;
        ELASTICACHE)
            cost=$(echo "$count * 40" | bc) # Rough estimate
            ;;
        ECS|EKS)
            # These services themselves are free, but the underlying EC2 instances are not
            # We're just estimating the control plane cost for EKS
            if [ "$service" = "EKS" ]; then
                cost=$(echo "$count * 75" | bc) # $75/month per EKS cluster
            fi
            ;;
        LAMBDA)
            # Hard to estimate without usage patterns, giving a modest default
            cost=5
            ;;
        ELB|ELBV2)
            cost=$(echo "$count * 20" | bc) # ~$20/month per load balancer
            ;;
        NAT)
            cost=$(echo "$count * 35" | bc) # ~$35/month per NAT gateway + data transfer
            ;;
        EIP)
            # Only count unattached EIPs (hard to determine from this output)
            # Assuming 50% are unattached
            unattached=$(echo "scale=0; $count / 2" | bc)
            cost=$(echo "$unattached * 3" | bc) # ~$3/month per unattached EIP
            ;;
        DYNAMODB)
            cost=$(echo "$count * 25" | bc) # Rough estimate for low usage tables
            ;;
        S3)
            # Hard to estimate without knowing storage amount
            cost=$(echo "$count * 5" | bc) # Minimal usage estimate
            ;;
        CLOUDFRONT)
            cost=$(echo "$count * 20" | bc) # Rough estimate for low traffic
            ;;
        ROUTE53)
            cost=$(echo "$count * 0.50" | bc) # $0.50 per hosted zone
            ;;
        ECR)
            cost=$(echo "$count * 10" | bc) # Rough estimate for storage
            ;;
        OPENSEARCH)
            cost=$(echo "$count * 80" | bc) # Rough estimate
            ;;
        SAGEMAKER)
            cost=$(echo "$count * 50" | bc) # Rough estimate for notebook instances
            ;;
        REDSHIFT)
            cost=$(echo "$count * 250" | bc) # Rough estimate for a small cluster
            ;;
        MSK)
            cost=$(echo "$count * 200" | bc) # Rough estimate
            ;;
        *)
            cost=0
            ;;
    esac

    # Make sure cost is a number
    if [ -z "$cost" ]; then
        cost=0
    fi

    # Add resource to found resources list if count > 0
    if [ "$count" -gt 0 ]; then
        echo "$service,$resource_type,$count,$cost" >> "$RESOURCES_FOUND_FILE"
    fi

    # Track costs by service in the file
    # Check if service already exists in the file
    if grep -q "^$service:" "$SERVICE_COSTS_FILE"; then
        # Update existing service
        current_cost=$(grep "^$service:" "$SERVICE_COSTS_FILE" | cut -d':' -f2)
        new_cost=$(echo "$current_cost + $cost" | bc)
        # Use different sed syntax for macOS
        sed -i '' "s/^$service:.*/$service:$new_cost/" "$SERVICE_COSTS_FILE" 2>/dev/null || sed -i "s/^$service:.*/$service:$new_cost/" "$SERVICE_COSTS_FILE"
    else
        # Add new service
        echo "$service:$cost" >> "$SERVICE_COSTS_FILE"
    fi

    # Update total cost
    TOTAL_ESTIMATED_COST=$(echo "$TOTAL_ESTIMATED_COST + $cost" | bc)
    
    echo $cost
}

# Function to safely run AWS commands with timeout
run_aws_command() {
    local command=$1
    local output
    
    # Run the command with a timeout and capture the output
    output=$(timeout 10s bash -c "$command" 2>/dev/null || echo "")
    
    echo "$output"
}

# Function to check resources in a specific region
check_region() {
    local region=$1
    echo -e "\n${YELLOW}Scanning region: ${region}${NC}"
    echo "-----------------------------------------------"

    # EC2 Instances
    echo -e "${GREEN}Checking EC2 instances...${NC}"
    INSTANCES=$(run_aws_command "aws ec2 describe-instances --region $region --query \"Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key=='Name'].Value|[0]]\" --output text")
    if [ -n "$INSTANCES" ]; then
        RUNNING_COUNT=$(echo "$INSTANCES" | grep -c "running" || echo "0")
        if [ "$RUNNING_COUNT" -gt 0 ]; then
            COST=$(estimate_cost "EC2" "instances" $RUNNING_COUNT "$INSTANCES")
            echo -e "${RED}Found $RUNNING_COUNT running EC2 instances (Est. \$$COST/month):${NC}"
            echo "$INSTANCES"
        else
            echo -e "Found EC2 instances (not running):"
            echo "$INSTANCES"
        fi
    else
        echo "No EC2 instances found."
    fi

    # EBS Volumes
    echo -e "\n${GREEN}Checking EBS volumes...${NC}"
    VOLUMES=$(run_aws_command "aws ec2 describe-volumes --region $region --query \"Volumes[*].[VolumeId,Size,State]\" --output text")
    if [ -n "$VOLUMES" ]; then
        VOLUME_COUNT=$(echo "$VOLUMES" | wc -l)
        COST=$(estimate_cost "EBS" "volumes" $VOLUME_COUNT "$VOLUMES")
        echo -e "${RED}Found $VOLUME_COUNT EBS volumes (Est. \$$COST/month):${NC}"
        echo "$VOLUMES"
    else
        echo "No EBS volumes found."
    fi

    # RDS Instances
    echo -e "\n${GREEN}Checking RDS instances...${NC}"
    RDS=$(run_aws_command "aws rds describe-db-instances --region $region --query \"DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceStatus]\" --output text")
    if [ -n "$RDS" ]; then
        RDS_COUNT=$(echo "$RDS" | wc -l)
        COST=$(estimate_cost "RDS" "instances" $RDS_COUNT "$RDS")
        echo -e "${RED}Found $RDS_COUNT RDS instances (Est. \$$COST/month):${NC}"
        echo "$RDS"
    else
        echo "No RDS instances found."
    fi

    # ElastiCache Clusters
    echo -e "\n${GREEN}Checking ElastiCache clusters...${NC}"
    ELASTICACHE=$(run_aws_command "aws elasticache describe-cache-clusters --region $region --query \"CacheClusters[*].[CacheClusterId,Engine,CacheClusterStatus]\" --output text")
    if [ -n "$ELASTICACHE" ]; then
        ELASTICACHE_COUNT=$(echo "$ELASTICACHE" | wc -l)
        COST=$(estimate_cost "ELASTICACHE" "clusters" $ELASTICACHE_COUNT "$ELASTICACHE")
        echo -e "${RED}Found $ELASTICACHE_COUNT ElastiCache clusters (Est. \$$COST/month):${NC}"
        echo "$ELASTICACHE"
    else
        echo "No ElastiCache clusters found."
    fi

    # ElastiCache Replication Groups
    echo -e "\n${GREEN}Checking ElastiCache replication groups...${NC}"
    ELASTICACHE_RG=$(run_aws_command "aws elasticache describe-replication-groups --region $region --query \"ReplicationGroups[*].[ReplicationGroupId,Status]\" --output text")
    if [ -n "$ELASTICACHE_RG" ]; then
        ELASTICACHE_RG_COUNT=$(echo "$ELASTICACHE_RG" | wc -l)
        COST=$(estimate_cost "ELASTICACHE" "replication-groups" $ELASTICACHE_RG_COUNT "$ELASTICACHE_RG")
        echo -e "${RED}Found $ELASTICACHE_RG_COUNT ElastiCache replication groups (Est. \$$COST/month):${NC}"
        echo "$ELASTICACHE_RG"
    else
        echo "No ElastiCache replication groups found."
    fi

    # ECS Clusters
    echo -e "\n${GREEN}Checking ECS clusters...${NC}"
    ECS=$(run_aws_command "aws ecs list-clusters --region $region --query \"clusterArns\" --output text")
    if [ -n "$ECS" ]; then
        ECS_COUNT=$(echo "$ECS" | wc -w)
        COST=$(estimate_cost "ECS" "clusters" $ECS_COUNT "$ECS")
        echo -e "${RED}Found $ECS_COUNT ECS clusters (Est. \$$COST/month):${NC}"
        echo "$ECS"
    else
        echo "No ECS clusters found."
    fi

    # EKS Clusters
    echo -e "\n${GREEN}Checking EKS clusters...${NC}"
    EKS=$(run_aws_command "aws eks list-clusters --region $region --query \"clusters\" --output text")
    if [ -n "$EKS" ]; then
        EKS_COUNT=$(echo "$EKS" | wc -w)
        COST=$(estimate_cost "EKS" "clusters" $EKS_COUNT "$EKS")
        echo -e "${RED}Found $EKS_COUNT EKS clusters (Est. \$$COST/month):${NC}"
        echo "$EKS"
    else
        echo "No EKS clusters found."
    fi

    # Lambda Functions
    echo -e "\n${GREEN}Checking Lambda functions...${NC}"
    LAMBDA=$(run_aws_command "aws lambda list-functions --region $region --query \"Functions[*].[FunctionName,Runtime]\" --output text")
    if [ -n "$LAMBDA" ]; then
        LAMBDA_COUNT=$(echo "$LAMBDA" | wc -l)
        COST=$(estimate_cost "LAMBDA" "functions" $LAMBDA_COUNT "$LAMBDA")
        echo -e "${RED}Found $LAMBDA_COUNT Lambda functions (Est. \$$COST/month):${NC}"
        echo "$LAMBDA"
    else
        echo "No Lambda functions found."
    fi

    # Load Balancers (ELB)
    echo -e "\n${GREEN}Checking Classic Load Balancers...${NC}"
    ELB=$(run_aws_command "aws elb describe-load-balancers --region $region --query \"LoadBalancerDescriptions[*].[LoadBalancerName]\" --output text")
    if [ -n "$ELB" ]; then
        ELB_COUNT=$(echo "$ELB" | wc -w)
        COST=$(estimate_cost "ELB" "load-balancers" $ELB_COUNT "$ELB")
        echo -e "${RED}Found $ELB_COUNT Classic Load Balancers (Est. \$$COST/month):${NC}"
        echo "$ELB"
    else
        echo "No Classic Load Balancers found."
    fi

    # Load Balancers (ALB/NLB)
    echo -e "\n${GREEN}Checking Application/Network Load Balancers...${NC}"
    ELBV2=$(run_aws_command "aws elbv2 describe-load-balancers --region $region --query \"LoadBalancers[*].[LoadBalancerName,Type]\" --output text")
    if [ -n "$ELBV2" ]; then
        ELBV2_COUNT=$(echo "$ELBV2" | wc -l)
        COST=$(estimate_cost "ELBV2" "load-balancers" $ELBV2_COUNT "$ELBV2")
        echo -e "${RED}Found $ELBV2_COUNT Application/Network Load Balancers (Est. \$$COST/month):${NC}"
        echo "$ELBV2"
    else
        echo "No Application/Network Load Balancers found."
    fi

    # NAT Gateways
    echo -e "\n${GREEN}Checking NAT Gateways...${NC}"
    NAT=$(run_aws_command "aws ec2 describe-nat-gateways --region $region --query \"NatGateways[*].[NatGatewayId,State]\" --output text")
    if [ -n "$NAT" ]; then
        NAT_COUNT=$(echo "$NAT" | wc -l)
        COST=$(estimate_cost "NAT" "gateways" $NAT_COUNT "$NAT")
        echo -e "${RED}Found $NAT_COUNT NAT Gateways (Est. \$$COST/month):${NC}"
        echo "$NAT"
    else
        echo "No NAT Gateways found."
    fi

    # Elastic IPs
    echo -e "\n${GREEN}Checking Elastic IPs...${NC}"
    EIP=$(run_aws_command "aws ec2 describe-addresses --region $region --query \"Addresses[*].[AllocationId,PublicIp]\" --output text")
    if [ -n "$EIP" ]; then
        EIP_COUNT=$(echo "$EIP" | wc -l)
        COST=$(estimate_cost "EIP" "elastic-ips" $EIP_COUNT "$EIP")
        echo -e "${RED}Found $EIP_COUNT Elastic IPs (Est. \$$COST/month):${NC}"
        echo "$EIP"
    else
        echo "No Elastic IPs found."
    fi

    # DynamoDB Tables
    echo -e "\n${GREEN}Checking DynamoDB tables...${NC}"
    DYNAMODB=$(run_aws_command "aws dynamodb list-tables --region $region --query \"TableNames\" --output text")
    if [ -n "$DYNAMODB" ]; then
        DYNAMODB_COUNT=$(echo "$DYNAMODB" | wc -w)
        COST=$(estimate_cost "DYNAMODB" "tables" $DYNAMODB_COUNT "$DYNAMODB")
        echo -e "${RED}Found $DYNAMODB_COUNT DynamoDB tables (Est. \$$COST/month):${NC}"
        echo "$DYNAMODB"
    else
        echo "No DynamoDB tables found."
    fi

    # S3 Buckets (global, but listing here for completeness)
    if [ "$region" = "us-east-1" ]; then
        echo -e "\n${GREEN}Checking S3 buckets...${NC}"
        S3=$(run_aws_command "aws s3 ls")
        if [ -n "$S3" ]; then
            S3_COUNT=$(echo "$S3" | wc -l)
            COST=$(estimate_cost "S3" "buckets" $S3_COUNT "$S3")
            echo -e "${RED}Found $S3_COUNT S3 buckets (Est. \$$COST/month):${NC}"
            echo "$S3"
        else
            echo "No S3 buckets found."
        fi
    fi

    # CloudFront Distributions (global, but listing here for completeness)
    if [ "$region" = "us-east-1" ]; then
        echo -e "\n${GREEN}Checking CloudFront distributions...${NC}"
        CF=$(run_aws_command "aws cloudfront list-distributions --query \"DistributionList.Items[*].[Id,Status,DomainName]\" --output text")
        if [ -n "$CF" ]; then
            CF_COUNT=$(echo "$CF" | wc -l)
            COST=$(estimate_cost "CLOUDFRONT" "distributions" $CF_COUNT "$CF")
            echo -e "${RED}Found $CF_COUNT CloudFront distributions (Est. \$$COST/month):${NC}"
            echo "$CF"
        else
            echo "No CloudFront distributions found."
        fi
    fi

    # Route53 Hosted Zones (global, but listing here for completeness)
    if [ "$region" = "us-east-1" ]; then
        echo -e "\n${GREEN}Checking Route53 hosted zones...${NC}"
        R53=$(run_aws_command "aws route53 list-hosted-zones --query \"HostedZones[*].[Id,Name]\" --output text")
        if [ -n "$R53" ]; then
            R53_COUNT=$(echo "$R53" | wc -l)
            COST=$(estimate_cost "ROUTE53" "hosted-zones" $R53_COUNT "$R53")
            echo -e "${RED}Found $R53_COUNT Route53 hosted zones (Est. \$$COST/month):${NC}"
            echo "$R53"
        else
            echo "No Route53 hosted zones found."
        fi
    fi

    # ECR Repositories
    echo -e "\n${GREEN}Checking ECR repositories...${NC}"
    ECR=$(run_aws_command "aws ecr describe-repositories --region $region --query \"repositories[*].[repositoryName]\" --output text")
    if [ -n "$ECR" ]; then
        ECR_COUNT=$(echo "$ECR" | wc -l)
        COST=$(estimate_cost "ECR" "repositories" $ECR_COUNT "$ECR")
        echo -e "${RED}Found $ECR_COUNT ECR repositories (Est. \$$COST/month):${NC}"
        echo "$ECR"
    else
        echo "No ECR repositories found."
    fi

    # OpenSearch Service Domains
    echo -e "\n${GREEN}Checking OpenSearch Service domains...${NC}"
    ES=$(run_aws_command "aws opensearch list-domain-names --region $region --query \"DomainNames[*].[DomainName]\" --output text")
    if [ -n "$ES" ]; then
        ES_COUNT=$(echo "$ES" | wc -l)
        COST=$(estimate_cost "OPENSEARCH" "domains" $ES_COUNT "$ES")
        echo -e "${RED}Found $ES_COUNT OpenSearch Service domains (Est. \$$COST/month):${NC}"
        echo "$ES"
    else
        echo "No OpenSearch Service domains found."
    fi

    # SageMaker Notebook Instances
    echo -e "\n${GREEN}Checking SageMaker notebook instances...${NC}"
    SM=$(run_aws_command "aws sagemaker list-notebook-instances --region $region --query \"NotebookInstances[*].[NotebookInstanceName,NotebookInstanceStatus]\" --output text")
    if [ -n "$SM" ]; then
        SM_COUNT=$(echo "$SM" | wc -l)
        COST=$(estimate_cost "SAGEMAKER" "notebook-instances" $SM_COUNT "$SM")
        echo -e "${RED}Found $SM_COUNT SageMaker notebook instances (Est. \$$COST/month):${NC}"
        echo "$SM"
    else
        echo "No SageMaker notebook instances found."
    fi

    # Redshift Clusters
    echo -e "\n${GREEN}Checking Redshift clusters...${NC}"
    REDSHIFT=$(run_aws_command "aws redshift describe-clusters --region $region --query \"Clusters[*].[ClusterIdentifier,ClusterStatus]\" --output text")
    if [ -n "$REDSHIFT" ]; then
        REDSHIFT_COUNT=$(echo "$REDSHIFT" | wc -l)
        COST=$(estimate_cost "REDSHIFT" "clusters" $REDSHIFT_COUNT "$REDSHIFT")
        echo -e "${RED}Found $REDSHIFT_COUNT Redshift clusters (Est. \$$COST/month):${NC}"
        echo "$REDSHIFT"
    else
        echo "No Redshift clusters found."
    fi

    # MSK Clusters
    echo -e "\n${GREEN}Checking MSK clusters...${NC}"
    MSK=$(run_aws_command "aws kafka list-clusters --region $region --query \"ClusterInfoList[*].[ClusterName,State]\" --output text")
    if [ -n "$MSK" ]; then
        MSK_COUNT=$(echo "$MSK" | wc -l)
        COST=$(estimate_cost "MSK" "clusters" $MSK_COUNT "$MSK")
        echo -e "${RED}Found $MSK_COUNT MSK clusters (Est. \$$COST/month):${NC}"
        echo "$MSK"
    else
        echo "No MSK clusters found."
    fi

    echo -e "\n${GREEN}Region scan completed: ${region}${NC}"
    echo "-----------------------------------------------"
}

# Iterate through all regions
for region in $REGIONS; do
    check_region $region
done

# Generate cost summary report
echo -e "\n${YELLOW}===== AWS COST FORECAST SUMMARY =====${NC}"
echo -e "${BLUE}Estimated Monthly Cost Breakdown:${NC}"
echo "-----------------------------------------------"

# Display resources found summary
echo -e "${YELLOW}Resources Found:${NC}"
echo "-----------------------------------------------"
if [ -s "$RESOURCES_FOUND_FILE" ]; then
    printf "%-15s %-20s %-10s %-15s\n" "SERVICE" "TYPE" "COUNT" "EST. COST/MONTH"
    echo "-----------------------------------------------"
    sort -t',' -k4 -nr "$RESOURCES_FOUND_FILE" | while IFS=, read -r service type count cost; do
        printf "%-15s %-20s %-10s \$%-15s\n" "$service" "$type" "$count" "$cost"
    done
else
    echo "No resources found that would incur charges."
fi

echo "-----------------------------------------------"

# Sort services by cost (high to low)
if [ -s "$SERVICE_COSTS_FILE" ]; then
    echo -e "${YELLOW}Service Cost Summary:${NC}"
    echo "-----------------------------------------------"
    printf "%-15s %-15s\n" "SERVICE" "EST. COST/MONTH"
    echo "-----------------------------------------------"
    sort -t':' -k2 -nr "$SERVICE_COSTS_FILE" | while IFS=: read -r service cost; do
        # Only show services with cost > 0
        if (( $(echo "$cost > 0" | bc -l) )); then
            printf "%-15s \$%-15s\n" "$service" "$cost"
        fi
    done
    echo "-----------------------------------------------"
fi

printf "${BLUE}%-15s \$%-15s${NC}\n" "TOTAL" "$TOTAL_ESTIMATED_COST"
echo "-----------------------------------------------"
echo -e "${YELLOW}DISCLAIMER:${NC} These are rough estimates based on standard pricing."
echo "Actual costs may vary based on usage patterns, reserved instances,"
echo "savings plans, and other AWS pricing factors."
echo "==============================================="

# Clean up temporary files
rm -f "$SERVICE_COSTS_FILE" "$RESOURCES_FOUND_FILE"

echo -e "\n${YELLOW}AWS account scan completed.${NC}"
echo "==============================================="
echo "Review the output above for any resources that might incur charges."
echo "Resources highlighted in RED are active and may be generating costs."
echo "==============================================="
echo -e "${GREEN}Usage:${NC} $0 [region1,region2,...]"
echo "Specify regions as a comma-separated list to scan only those regions."
echo "Example: $0 us-east-1,us-west-2"
