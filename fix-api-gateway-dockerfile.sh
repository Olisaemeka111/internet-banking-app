#!/bin/bash

# This script fixes the API Gateway Dockerfile issue by ensuring it uses the correct JAR file

# Navigate to the API Gateway directory
cd "/Users/olisa/Desktop/Internet banking  app/internet-banking-concept-microservices/internet-banking-api-gateway"

# Create a new Dockerfile that explicitly uses the API Gateway JAR
cat > Dockerfile << 'EOF'
FROM eclipse-temurin:21.0.2_13-jre-alpine
LABEL maintainer="chinthaka@javatodev.com"
VOLUME /main-app
ADD build/libs/internet-banking-api-gateway-0.0.1-SNAPSHOT.jar /app/app.jar
EXPOSE 8082
COPY wait-for-it.sh wait-for-it.sh
RUN chmod +x wait-for-it.sh
# Add bash for wait-for-it.sh
RUN apk add --no-cache bash
ENTRYPOINT ["java", "-jar", "-Dspring.profiles.active=docker", "/app/app.jar"]
EOF

# Update the buildspec.yml to ensure it uses the correct JAR file
cat > buildspec.yml << 'EOF'
version: 0.2

phases:
  install:
    runtime-versions:
      java: corretto11
    commands:
      - echo Installing dependencies...
      - yum install -y curl

  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
      # Use direct image references to avoid Docker Hub rate limits
      - echo Using direct ECR Public Gallery references to avoid rate limits...
      - REPOSITORY_URI=$ECR_REPOSITORY_URI
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
      - echo Repository URI $REPOSITORY_URI
      - echo Image tag $IMAGE_TAG
      - ls -la
  
  build:
    commands:
      - echo Build started on `date`
      - ls -la
      - echo Building the application with Gradle...
      - chmod +x ./gradlew
      - ./gradlew clean build -x test --warning-mode all --stacktrace
      - echo Building the Docker image...
      # Pull base images before building to avoid rate limits
      - docker pull eclipse-temurin:21.0.2_13-jre-alpine || true
      - pwd
      - ls -la
      - echo "FROM eclipse-temurin:21.0.2_13-jre-alpine" > Dockerfile
      - echo "LABEL maintainer=\"chinthaka@javatodev.com\"" >> Dockerfile
      - echo "VOLUME /main-app" >> Dockerfile
      - echo "ADD build/libs/internet-banking-api-gateway-0.0.1-SNAPSHOT.jar /app/app.jar" >> Dockerfile
      - echo "EXPOSE 8082" >> Dockerfile
      - echo "COPY wait-for-it.sh wait-for-it.sh" >> Dockerfile
      - echo "RUN chmod +x wait-for-it.sh" >> Dockerfile
      - echo "RUN apk add --no-cache bash" >> Dockerfile
      - echo "ENTRYPOINT [\"java\", \"-jar\", \"-Dspring.profiles.active=docker\", \"/app/app.jar\"]" >> Dockerfile
      - cat Dockerfile
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - mkdir -p /codebuild/output
      - cd /codebuild/output
      - echo "[{\"name\":\"internet-banking-api-gateway\",\"imageUri\":\"${REPOSITORY_URI}:${IMAGE_TAG}\"}]" > imagedefinitions.json
      - cat imagedefinitions.json
      - echo "Preparing task definition and appspec files..."
      - cp $CODEBUILD_SRC_DIR/internet-banking-concept-microservices/internet-banking-api-gateway/appspec.yml /codebuild/output/
      - cp $CODEBUILD_SRC_DIR/internet-banking-concept-microservices/internet-banking-api-gateway/taskdef.json /codebuild/output/
      - sed -i "s|<IMAGE_NAME>|${REPOSITORY_URI}:${IMAGE_TAG}|g" /codebuild/output/taskdef.json
      - sed -i "s|<TASK_DEFINITION>|arn:aws:ecs:us-east-1:156041437006:task-definition/dev-internet-banking-api-gateway:2|g" /codebuild/output/appspec.yml
      - ls -la /codebuild/output

artifacts:
  files:
    - imagedefinitions.json
    - appspec.yml
    - taskdef.json
EOF

echo "API Gateway Dockerfile and buildspec.yml have been updated."

# Create a new task definition JSON file with the correct image
cd "/Users/olisa/Desktop/Internet banking  app"

cat > api-gateway-task-definition-fixed.json << 'EOF'
{
  "family": "dev-internet-banking-api-gateway",
  "executionRoleArn": "arn:aws:iam::156041437006:role/dev-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::156041437006:role/dev-ecs-task-role",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "name": "internet-banking-api-gateway",
      "image": "156041437006.dkr.ecr.us-east-1.amazonaws.com/internet-banking-api-gateway:latest",
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

echo "API Gateway task definition has been created."
