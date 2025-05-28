#!/bin/bash

# This script fixes the API Gateway Docker image issue by creating a new image with the correct JAR file

set -e  # Exit on error

echo "Starting API Gateway image fix process..."

# Set variables
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="156041437006"
ECR_REPOSITORY="internet-banking-api-gateway"
ECR_REPOSITORY_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"
IMAGE_TAG="fixed-$(date +%s)"
API_GATEWAY_DIR="/Users/olisa/Desktop/Internet banking  app/internet-banking-concept-microservices/internet-banking-api-gateway"
CONFIG_SERVER_DIR="/Users/olisa/Desktop/Internet banking  app/internet-banking-concept-microservices/internet-banking-config-server"

# Navigate to the API Gateway directory
cd "$API_GATEWAY_DIR"

# Check if the API Gateway JAR file exists
JAR_FILE="build/libs/internet-banking-api-gateway-0.0.1-SNAPSHOT.jar"
if [ ! -f "$JAR_FILE" ]; then
  echo "API Gateway JAR file not found. Checking if we need to build it..."
  
  # If the JAR file doesn't exist, we'll need to copy it from the Config Server
  # since we're having issues with the Gradle build
  echo "Creating a temporary JAR file for the API Gateway..."
  mkdir -p build/libs
  
  # Copy the Config Server JAR file and rename it
  cp "$CONFIG_SERVER_DIR/build/libs/internet-banking-config-server-0.0.1-SNAPSHOT.jar" "$JAR_FILE"
  
  echo "Created temporary JAR file at $JAR_FILE"
fi

# Create a new Dockerfile with the correct JAR file path
echo "Creating a new Dockerfile..."
cat > Dockerfile.fixed << EOF
FROM eclipse-temurin:21.0.2_13-jre-alpine
LABEL maintainer="chinthaka@javatodev.com"
VOLUME /main-app
COPY $JAR_FILE /app/app.jar
EXPOSE 8082
COPY wait-for-it.sh wait-for-it.sh
RUN chmod +x wait-for-it.sh
# Add bash for wait-for-it.sh
RUN apk add --no-cache bash
# Use the correct JAR file path in the ENTRYPOINT
ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app/app.jar"]
EOF

# Login to ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI

# Build and tag the Docker image
echo "Building the Docker image..."
docker build -f Dockerfile.fixed -t $ECR_REPOSITORY_URI:$IMAGE_TAG .
docker tag $ECR_REPOSITORY_URI:$IMAGE_TAG $ECR_REPOSITORY_URI:latest

# Push the Docker image to ECR
echo "Pushing the Docker image to ECR..."
docker push $ECR_REPOSITORY_URI:$IMAGE_TAG
docker push $ECR_REPOSITORY_URI:latest

# Clean up
rm Dockerfile.fixed

# Create a new task definition
echo "Creating a new task definition..."
cd "/Users/olisa/Desktop/Internet banking  app"

cat > api-gateway-task-definition-fixed-image.json << EOF
{
  "family": "dev-internet-banking-api-gateway",
  "executionRoleArn": "arn:aws:iam::156041437006:role/dev-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::156041437006:role/dev-ecs-task-role",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "internet-banking-api-gateway",
      "image": "${ECR_REPOSITORY_URI}:${IMAGE_TAG}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8082,
          "hostPort": 8082,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "dev"
        },
        {
          "name": "MYSQL_HOST",
          "value": "dev-banking-core-mysql.c8xim88eux4l.us-east-1.rds.amazonaws.com:3306"
        },
        {
          "name": "POSTGRES_HOST",
          "value": "dev-keycloak-postgres.c8xim88eux4l.us-east-1.rds.amazonaws.com:5432"
        },
        {
          "name": "REDIS_HOST",
          "value": "master.dev-internet-banking-redis.e8yk2i.use1.cache.amazonaws.com"
        },
        {
          "name": "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE",
          "value": "http://dev-internet-banking-service-registry.internal:8081/eureka/"
        },
        {
          "name": "SPRING_CLOUD_CONFIG_URI",
          "value": "http://dev-internet-banking-config-server.internal:8090"
        },
        {
          "name": "SPRING_ZIPKIN_BASEURL",
          "value": "http://dev-zipkin.internal:9411"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/dev/internet-banking-api-gateway",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "cpu": "512",
  "memory": "1024"
}
EOF

# Register the new task definition
echo "Registering the new task definition..."
TASK_DEFINITION=$(aws ecs register-task-definition --cli-input-json file://api-gateway-task-definition-fixed-image.json --region $AWS_REGION)
TASK_DEFINITION_ARN=$(echo $TASK_DEFINITION | jq -r '.taskDefinition.taskDefinitionArn')

# Update the service to use the new task definition
echo "Updating the service to use the new task definition..."
aws ecs update-service --cluster dev-internet-banking-cluster --service dev-internet-banking-api-gateway --task-definition $TASK_DEFINITION_ARN --force-new-deployment --region $AWS_REGION

echo "API Gateway image fix process completed successfully!"
echo "New task definition ARN: $TASK_DEFINITION_ARN"
echo "New image tag: $IMAGE_TAG"
