# Internet Banking Application Deployment Fixes

## Overview

This document summarizes all the fixes implemented to resolve the deployment issues with the Internet Banking application. The primary issues were related to Docker container configuration, Terraform settings, and service dependencies.

## Key Issues Fixed

### 1. Docker Container Configuration

#### Config Server
- **Issue**: The container was failing with "Error: Unable to access jarfile /app/*.jar" because the Java runtime was trying to find a literal file named "*.jar" instead of expanding the wildcard.
- **Fix**: Updated the Dockerfile to use a specific JAR file path:
  ```diff
  - ADD build/libs/internet-banking-config-server-0.0.1-SNAPSHOT.jar app.jar
  + ADD build/libs/internet-banking-config-server-0.0.1-SNAPSHOT.jar /app/app.jar
  - ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app.jar"]
  + ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app/app.jar"]
  ```

#### API Gateway
- **Issue**: Similar to the Config Server, the API Gateway was using an incorrect JAR file path.
- **Fix**: Updated the Dockerfile to use a specific JAR file path:
  ```diff
  - ADD build/libs/internet-banking-api-gateway-0.0.1-SNAPSHOT.jar app.jar
  + ADD build/libs/internet-banking-api-gateway-0.0.1-SNAPSHOT.jar /app/app.jar
  - ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app.jar"]
  + ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app/app.jar"]
  ```

#### Service Registry
- **Issue**: Same issue with the JAR file path.
- **Fix**: Updated the Dockerfile to use a specific JAR file path:
  ```diff
  - ADD build/libs/internet-banking-service-registry-0.0.1-SNAPSHOT.jar app.jar
  + ADD build/libs/internet-banking-service-registry-0.0.1-SNAPSHOT.jar /app/app.jar
  - ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app.jar"]
  + ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app/app.jar"]
  ```

### 2. Terraform Configuration

#### Service Definitions
- **Issue**: The service definitions in variables.tf were using Docker Hub images instead of ECR images, and some had incorrect resource allocations.
- **Fix**: Updated the service definitions to use ECR images and adjusted resource allocations:
  ```hcl
  config_server = {
    name                 = "internet-banking-config-server"
    container_port       = 8090
    host_port            = 8090
    cpu                  = 256
    memory               = 512
    desired_count        = 2
    max_capacity         = 4
    image                = "156041437006.dkr.ecr.us-east-1.amazonaws.com/internet-banking-config-server:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  }
  ```

#### Health Check Grace Period
- **Issue**: The health check grace period was too short (60 seconds), not giving the services enough time to start up.
- **Fix**: Increased the health check grace period to 300 seconds (5 minutes):
  ```diff
  - health_check_grace_period_seconds  = 60
  + health_check_grace_period_seconds  = 300
  ```

#### Environment Variables
- **Issue**: Missing environment variables for service discovery and configuration.
- **Fix**: Added environment variables for Eureka, Config Server, and Zipkin:
  ```hcl
  environment = [
    # Existing variables...
    {
      name  = "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE"
      value = "http://dev-internet-banking-service-registry.internal:8081/eureka/"
    },
    {
      name  = "SPRING_CLOUD_CONFIG_URI"
      value = "http://dev-internet-banking-config-server.internal:8090"
    },
    {
      name  = "SPRING_ZIPKIN_BASEURL"
      value = "http://dev-zipkin.internal:9411"
    }
  ]
  ```

### 3. Build Process

#### buildspec.yml
- **Issue**: The buildspec.yml files were not consistently creating Dockerfiles with the correct JAR file paths.
- **Fix**: Created specific buildspec.yml files for each service to ensure they use the correct JAR file paths:
  ```yaml
  - echo "ADD build/libs/internet-banking-api-gateway-0.0.1-SNAPSHOT.jar /app/app.jar" >> Dockerfile
  - echo "ENTRYPOINT [\"java\", \"-jar\", \"-Dspring.profiles.active=docker\", \"/app/app.jar\"]" >> Dockerfile
  ```

### 4. IAM Permissions

- **Issue**: Insufficient IAM permissions for the CodePipeline role to deploy to ECS.
- **Fix**: Created comprehensive IAM policies for both CodePipeline and ECS roles:
  ```hcl
  resource "aws_iam_policy" "ecs_task_execution_enhanced_policy" {
    # Policy definition for ECS task execution role
  }
  
  resource "aws_iam_policy" "ecs_task_enhanced_policy" {
    # Policy definition for ECS task role
  }
  ```

## Deployment Process

1. Fixed Dockerfiles for all services to use the correct JAR file paths
2. Created specific buildspec.yml files for each service
3. Updated Terraform configurations for service definitions and environment variables
4. Increased health check grace period to give services more time to start up
5. Created enhanced IAM policies for ECS tasks
6. Triggered pipelines for the Config Server, API Gateway, and Service Registry services

## Application URL

The application is accessible through the public ALB:
```
https://dev-public-alb-16320014.us-east-1.elb.amazonaws.com
```

## Monitoring and Troubleshooting

To monitor the status of the services:
```bash
# Check pipeline status
aws codepipeline get-pipeline-state --name dev-internet-banking-api-gateway-pipeline --region us-east-1

# Check ECS service status
aws ecs describe-services --cluster dev-internet-banking-cluster --services dev-internet-banking-api-gateway --region us-east-1

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region us-east-1
```

## Future Improvements

1. Implement a more robust service discovery mechanism
2. Add health checks and readiness probes for all services
3. Implement circuit breakers for service dependencies
4. Set up proper logging and monitoring for all services
5. Create a CI/CD pipeline for infrastructure changes
