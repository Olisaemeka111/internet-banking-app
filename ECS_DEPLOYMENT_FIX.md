# ECS Deployment Fix Documentation

## Overview

This document outlines the changes made to fix the ECS deployment issues in the Internet Banking application. The primary issue was that the Docker container was failing with the error "Error: Unable to access jarfile /app/*.jar" because the Java runtime was trying to find a literal file named "*.jar" instead of expanding the wildcard.

## Changes Made

### 1. Dockerfile Updates

The Dockerfile for the config server has been updated to use a specific JAR file path instead of a wildcard:

```diff
- ADD build/libs/internet-banking-config-server-0.0.1-SNAPSHOT.jar app.jar
+ ADD build/libs/internet-banking-config-server-0.0.1-SNAPSHOT.jar /app/app.jar
- ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app.jar"]
+ ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app/app.jar"]
```

### 2. Buildspec.yml Updates

The buildspec.yml file has been updated to prevent it from generating a new Dockerfile with a wildcard pattern:

```diff
- echo "COPY ${JAR_FILE} /app/app.jar" >> Dockerfile
- echo "ENTRYPOINT [\"java\", \"-jar\", \"/app/app.jar\"]" >> Dockerfile
+ echo "COPY build/libs/internet-banking-config-server-0.0.1-SNAPSHOT.jar /app/app.jar" >> Dockerfile
+ echo "ENTRYPOINT [\"java\", \"-jar\", \"-Dspring.profiles.active=docker\", \"/app/app.jar\"]" >> Dockerfile
```

### 3. Terraform Updates

#### 3.1 Service Definition Updates

The service definition in the Terraform variables.tf file has been updated to match the current task definition:

```diff
config_server = {
  name                 = "internet-banking-config-server"
  container_port       = 8090
  host_port            = 8090
- cpu                  = 512
- memory               = 1024
+ cpu                  = 256
+ memory               = 512
  desired_count        = 2
  max_capacity         = 4
- image                = "javatodev/internet-banking-config-server:latest"
+ image                = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/internet-banking-config-server:latest"
  health_check_path    = "/actuator/health"
  requires_public_access = false
}
```

#### 3.2 IAM Policy Updates

New IAM policies have been created to ensure the CodePipeline role and ECS task roles have the necessary permissions:

1. **ECS Deploy Action Policy**: Allows the CodePipeline role to deploy to ECS
2. **CodePipeline ECS Deployment Policy**: Provides more comprehensive permissions for ECS deployments
3. **ECS Task Execution Enhanced Policy**: Ensures the ECS task execution role can pull images from ECR and write logs to CloudWatch
4. **ECS Task Enhanced Policy**: Provides additional permissions for the ECS task role

## How to Apply These Changes

1. Push the updated Dockerfile and buildspec.yml to your repository
2. Apply the Terraform changes with:
   ```
   terraform apply
   ```
3. Trigger a new pipeline execution to deploy the updated configuration

## Verification

After applying these changes, the ECS deployment should succeed with the following indicators:

1. The ECS task should start successfully without the "Error: Unable to access jarfile /app/*.jar" error
2. The Spring Boot application should initialize correctly with the "docker" profile
3. The ECS service should show a stable number of running tasks matching the desired count

## Troubleshooting

If you encounter any issues after applying these changes:

1. Check the CloudWatch logs for the ECS tasks to see if there are any new errors
2. Verify that the IAM roles have the correct permissions
3. Ensure the ECR repository contains the correct Docker image with the fixed Dockerfile
4. Check the CodePipeline execution logs for any errors during the deployment stage
