# Internet Banking Microservices - AWS Terraform Deployment

This repository contains Terraform configurations for deploying the Internet Banking Microservices application on AWS. The infrastructure is designed to be scalable, highly available, and secure, following AWS best practices.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Module Descriptions](#module-descriptions)
- [Environment Configurations](#environment-configurations)
- [Deployment Instructions](#deployment-instructions)
- [Post-Deployment Steps](#post-deployment-steps)
- [Monitoring and Operations](#monitoring-and-operations)
- [Security Considerations](#security-considerations)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

The infrastructure deploys the Internet Banking Microservices application with the following AWS services:

- **Amazon VPC**: Network isolation with public and private subnets across multiple Availability Zones
- **Amazon ECS (Fargate)**: Container orchestration for microservices
- **Amazon RDS**: MySQL for core banking data and PostgreSQL for Keycloak
- **Amazon ElastiCache**: Redis for caching and session management
- **AWS API Gateway**: API management and routing
- **Amazon Route 53**: DNS management
- **AWS Certificate Manager**: SSL/TLS certificate management
- **Amazon CloudWatch**: Monitoring, logging, and alerting
- **AWS WAF**: Web Application Firewall for security
- **AWS CodePipeline & CodeBuild**: CI/CD and security scanning

The architecture follows a multi-tier design with:
- Public-facing load balancers in public subnets
- Application services in private subnets
- Databases and caches in isolated private subnets

## Infrastructure Diagram

```
+----------------------------------------------------------------------------------------------------------+
|                                            AWS Cloud                                                      |
+----------------------------------------------------------------------------------------------------------+
|                                                                                                          |
|  +------------------------------------+  +------------------------------------+                            |
|  |           Region: us-east-1       |  |           Route53                 |                            |
|  +------------------------------------+  |                                    |                            |
|  |                                    |  |  +----------------------------+   |                            |
|  |  +----------------------------+    |  |  |     Hosted Zone           |   |                            |
|  |  |          VPC              |    |  |  +----------------------------+   |                            |
|  |  +----------------------------+    |  +------------------------------------+                            |
|  |  |                            |    |                                                                   |
|  |  |  +---------------------+   |    |  +------------------------------------+                            |
|  |  |  |  Public Subnet AZ1  |   |    |  |             WAF                   |                            |
|  |  |  +---------------------+   |    |  |                                    |                            |
|  |  |  | Internet Gateway    |   |    |  |  +----------------------------+   |                            |
|  |  |  | NAT Gateway         |   |    |  |  |      Web ACL              |   |                            |
|  |  |  | Public ALB          |<--|-------|--|      Rules                |   |                            |
|  |  |  +---------------------+   |    |  |  +----------------------------+   |                            |
|  |  |                            |    |  +------------------------------------+                            |
|  |  |  +---------------------+   |    |                                                                   |
|  |  |  |  Public Subnet AZ2  |   |    |  +------------------------------------+                            |
|  |  |  +---------------------+   |    |  |         CloudWatch               |                            |
|  |  |  | NAT Gateway         |   |    |  |                                    |                            |
|  |  |  +---------------------+   |    |  |  +----------------------------+   |                            |
|  |  |                            |    |  |  |      Dashboards           |   |                            |
|  |  |  +---------------------+   |    |  |  |      Log Groups           |   |                            |
|  |  |  | Private Subnet AZ1  |   |    |  |  |      Alarms               |   |                            |
|  |  |  +---------------------+   |    |  |  |      Metrics              |   |                            |
|  |  |  | ECS Services:       |   |    |  |  +----------------------------+   |                            |
|  |  |  | - API Gateway       |   |    |  +------------------------------------+                            |
|  |  |  | - Core Banking       |   |    |                                                                   |
|  |  |  | - Fund Transfer      |   |    |  +------------------------------------+                            |
|  |  |  | - User Service       |   |    |  |         CodePipeline              |                            |
|  |  |  | - Utility Payment    |   |    |  |                                    |                            |
|  |  |  | - Keycloak           |   |    |  |  +----------------------------+   |                            |
|  |  |  | - Zipkin             |   |    |  |  |      Security Scanning    |   |                            |
|  |  |  +---------------------+   |    |  |  +----------------------------+   |                            |
|  |  |                            |    |  +------------------------------------+                            |
|  |  |  +---------------------+   |    |                                                                   |
|  |  |  | Private Subnet AZ2  |   |    |  +------------------------------------+                            |
|  |  |  +---------------------+   |    |  |         Service Discovery         |                            |
|  |  |  | ECS Services:       |   |    |  |                                    |                            |
|  |  |  | - Config Server     |   |    |  |  +----------------------------+   |                            |
|  |  |  | - Service Registry  |   |    |  |  |      Private DNS          |   |                            |
|  |  |  | Network LB          |   |    |  |  |      Namespace            |   |                            |
|  |  |  | Internal ALB        |   |    |  |  +----------------------------+   |                            |
|  |  |  +---------------------+   |    |  +------------------------------------+                            |
|  |  |                            |    |                                                                   |
|  |  |  +---------------------+   |    |  +------------------------------------+                            |
|  |  |  | Database Subnet AZ1 |   |    |  |         RDS                       |                            |
|  |  |  +---------------------+   |    |  |                                    |                            |
|  |  |  | MySQL RDS           |   |    |  |  +----------------------------+   |                            |
|  |  |  | PostgreSQL RDS      |   |    |  |  |      MySQL Instance       |   |                            |
|  |  |  +---------------------+   |    |  |  |      PostgreSQL Instance  |   |                            |
|  |  |                            |    |  |  +----------------------------+   |                            |
|  |  |  +---------------------+   |    |  +------------------------------------+                            |
|  |  |  | Database Subnet AZ2 |   |    |                                                                   |
|  |  |  +---------------------+   |    |  +------------------------------------+                            |
|  |  |  | Redis ElastiCache   |   |    |  |         ElastiCache               |                            |
|  |  |  +---------------------+   |    |  |                                    |                            |
|  |  |                            |    |  |  +----------------------------+   |                            |
|  |  +----------------------------+    |  |  |      Redis Cluster        |   |                            |
|  |                                    |  |  +----------------------------+   |                            |
|  +------------------------------------+  +------------------------------------+                            |
|                                                                                                          |
+----------------------------------------------------------------------------------------------------------+
```

### Network Flow and Connectivity

1. **External Traffic Flow**:
   - Internet traffic enters through the Internet Gateway
   - Passes through WAF for security filtering
   - Routed to the Public Application Load Balancer in public subnets
   - ALB routes traffic to ECS services in private subnets

2. **Internal Service Communication**:
   - Microservices communicate via Service Discovery (AWS Cloud Map)
   - Internal Application Load Balancer handles service-to-service traffic
   - Network Load Balancer supports API Gateway VPC Link integration

3. **Data Tier Access**:
   - ECS services in private subnets connect to:
     - RDS MySQL for core banking data
     - RDS PostgreSQL for Keycloak authentication
     - ElastiCache Redis for caching and session management

4. **Monitoring and Security**:
   - CloudWatch collects logs and metrics from all components
   - WAF protects public endpoints from common web exploits
   - Security scanning pipeline continuously checks infrastructure for vulnerabilities

## Prerequisites

Before deploying this infrastructure, you need:

1. **AWS Account**: Active AWS account with appropriate permissions
2. **AWS CLI**: Configured with appropriate credentials
3. **Terraform**: Version 1.0.0 or later installed
4. **S3 Bucket**: For Terraform state storage (one per environment)
5. **DynamoDB Table**: For state locking (one per environment)
6. **Domain Name**: Registered domain name (optional, but recommended for production)
7. **SSL Certificate**: In AWS Certificate Manager (for HTTPS)

## Repository Structure

```
terraform/
├── main.tf                # Main configuration file
├── variables.tf           # Variable definitions
├── modules/               # Reusable modules
│   ├── vpc/               # Network infrastructure
│   ├── security/          # Security groups
│   ├── rds/               # Database resources
│   ├── elasticache/       # Redis caching
│   ├── ecs/               # Container orchestration
│   ├── api_gateway/       # API management
│   ├── route53/           # DNS management
│   └── monitoring/        # CloudWatch monitoring
└── environments/          # Environment-specific configs
    ├── dev/
    │   ├── main.tf        # Dev environment configuration
    │   └── terraform.tfvars # Dev environment variables
    ├── staging/
    │   ├── main.tf        # Staging environment configuration
    │   └── terraform.tfvars # Staging environment variables
    └── prod/
        ├── main.tf        # Production environment configuration
        └── terraform.tfvars # Production environment variables
```

## Module Descriptions

### VPC Module
Creates a Virtual Private Cloud with public and private subnets across multiple Availability Zones, including Internet Gateway, NAT Gateways, and route tables.

**Key Resources:**
- VPC with CIDR block
- Public and private subnets
- Internet Gateway and NAT Gateways
- Route tables and associations
- VPC Flow Logs for network monitoring

### Security Module
Defines security groups for all services, controlling inbound and outbound traffic.

**Key Resources:**
- API Gateway security group
- ECS services security group
- Database security groups (MySQL, PostgreSQL)
- Redis security group

### RDS Module
Provisions MySQL and PostgreSQL databases with appropriate configurations.

**Key Resources:**
- MySQL RDS instance for core banking data
- PostgreSQL RDS instance for Keycloak
- Subnet groups and parameter groups
- Automated backups and maintenance windows

### ElastiCache Module
Sets up Redis clusters for caching and session management.

**Key Resources:**
- Redis replication group
- Subnet group and parameter group
- Encryption and maintenance configuration

### ECS Module
Deploys container services using Amazon ECS with Fargate.

**Key Resources:**
- ECS cluster
- Task definitions for each microservice
- ECS services with auto-scaling
- Application Load Balancers
- CloudWatch log groups

### API Gateway Module
Configures API Gateway for managing API endpoints.

**Key Resources:**
- REST API with resources and methods
- VPC Link for private integration
- Custom domain name
- API deployment and stage

### Route53 Module
Sets up DNS records for the application.

**Key Resources:**
- Hosted zone for the domain
- A records for API Gateway and other endpoints

### Monitoring Module
Implements CloudWatch dashboards, alarms, and metrics.

**Key Resources:**
- CloudWatch dashboard
- Metric alarms for CPU, memory, and other resources
- SNS topic for alarm notifications
- Log metric filters

## Environment Configurations

The infrastructure supports three environments, each with its own configuration:

### Development (Dev)
- Minimal resources for cost optimization
- Single instance of each service
- Simplified configuration for rapid development
- Less stringent security and availability requirements

### Staging
- Moderate resources for testing
- Multiple instances for basic redundancy
- Configuration similar to production
- Used for integration testing and pre-production validation

### Production (Prod)
- Full resources for high availability and performance
- Multiple instances across Availability Zones
- Enhanced security measures
- Automated scaling for handling production loads

## Deployment Instructions

### 1. Prepare AWS Account

1. Create an S3 bucket for Terraform state:
   ```bash
   aws s3 mb s3://internet-banking-terraform-state-<env>
   aws s3api put-bucket-versioning --bucket internet-banking-terraform-state-<env> --versioning-configuration Status=Enabled
   ```

2. Create a DynamoDB table for state locking:
   ```bash
   aws dynamodb create-table \
     --table-name terraform-lock-<env> \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

3. (Optional) Create an SSL certificate in AWS Certificate Manager:
   ```bash
   aws acm request-certificate \
     --domain-name <your-domain-name> \
     --validation-method DNS \
     --subject-alternative-names *.example.com
   ```

### 2. Configure Environment Variables

1. Review and update the `terraform.tfvars` file in the appropriate environment directory:
   - Update domain name
   - Set database credentials (use AWS Secrets Manager for production)
   - Adjust resource allocations if needed

### 3. Initialize Terraform

Navigate to the appropriate environment directory and initialize Terraform:

```bash
cd terraform/environments/<env>
terraform init
```

### 4. Plan Deployment

Generate and review the execution plan:

```bash
terraform plan
```

Review the plan carefully to ensure it matches your expectations.

### 5. Apply Configuration

Apply the Terraform configuration:

```bash
terraform apply
```

Review the changes one more time and type `yes` to confirm.

### 6. Verify Deployment

After deployment completes, verify the infrastructure:

```bash
terraform output
```

This will show important outputs like load balancer DNS names and database endpoints.

## Post-Deployment Steps

After successful deployment, perform these additional steps:

1. **Update DNS Records**: If using your own domain, update DNS records to point to the created resources.

2. **Configure Keycloak**: Access the Keycloak admin console and configure realms, clients, and users.

3. **Verify Connectivity**: Test connectivity between services using the provided endpoints.

4. **Set Up Monitoring**: Configure additional CloudWatch alarms and notifications as needed.

5. **Enable AWS Config**: For compliance monitoring and resource tracking.

6. **Set Up AWS Backup**: For additional backup protection beyond RDS automated backups.

## Monitoring and Operations

### CloudWatch Dashboards
Access the CloudWatch dashboard created by the monitoring module to view:
- CPU and memory utilization
- Database performance metrics
- API Gateway request metrics
- Error rates and latency

### Alarms
The deployment sets up alarms for:
- High CPU/memory utilization
- Database connection issues
- Error rate thresholds
- Low storage space

### Logs
All services send logs to CloudWatch Log Groups:
- ECS service logs
- RDS database logs
- API Gateway access logs
- VPC Flow Logs

## Security Considerations

### Data Protection
- All data is encrypted at rest using AWS-managed keys
- All traffic between services uses TLS
- Sensitive data should be stored in AWS Secrets Manager

### Network Security
- Services are deployed in private subnets
- Security groups restrict traffic to necessary ports
- Only the API Gateway is exposed to the internet

### Authentication
- Keycloak provides OAuth2/OpenID Connect authentication
- IAM roles control access to AWS resources
- Database credentials are restricted to necessary permissions

## Cost Optimization

To optimize costs:
- Scale down resources in non-production environments
- Use Auto Scaling to match capacity with demand
- Consider Reserved Instances for RDS and ElastiCache
- Set up AWS Cost Explorer and Budgets for monitoring

## Troubleshooting

### Common Issues

1. **Terraform State Lock Issues**:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **Service Discovery Problems**:
   - Check security groups allow traffic between services
   - Verify ECS services are running with correct task definitions
   - Check CloudWatch Logs for connection errors

3. **Database Connection Issues**:
   - Verify security group rules
   - Check credentials in environment variables
   - Ensure database is in "available" state

4. **API Gateway 5xx Errors**:
   - Check target service health
   - Verify VPC Link configuration
   - Review CloudWatch Logs for API Gateway

### Getting Help

For additional assistance:
- Check AWS documentation
- Review Terraform module documentation
- Consult with AWS Support if needed

---

This Terraform configuration provides a complete infrastructure for the Internet Banking Microservices application, following AWS best practices for security, scalability, and high availability.
