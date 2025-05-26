environment = "prod"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

# Database Configuration - In production, use AWS Secrets Manager instead of hardcoded values
mysql_db_name     = "banking_core"
mysql_username    = "admin"
mysql_password    = "PLACEHOLDER_TO_BE_REPLACED_WITH_SECRETS_MANAGER"
postgres_db_name  = "keycloak"
postgres_username = "keycloak"
postgres_password = "PLACEHOLDER_TO_BE_REPLACED_WITH_SECRETS_MANAGER"

# Domain Configuration
domain_name = "internetbanking-example.com"
certificate_arn = null  # Will be created manually in ACM for production environment

# WAF Configuration
waf_allowed_countries = ["US", "CA", "GB", "DE", "FR", "AU", "JP", "SG"]

# Cross-Region Backup Configuration
enable_cross_region_backup = true
backup_kms_key_id = null  # Will be created manually in KMS
backup_sns_topic_arn = null  # Will be created as part of deployment

# Service Configuration - High availability for production environment
services = {
  config_server = {
    name                 = "internet-banking-config-server"
    container_port       = 8090
    host_port            = 8090
    cpu                  = 1024
    memory               = 2048
    desired_count        = 3
    max_capacity         = 6
    image                = "javatodev/internet-banking-config-server:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  },
  service_registry = {
    name                 = "internet-banking-service-registry"
    container_port       = 8081
    host_port            = 8081
    cpu                  = 1024
    memory               = 2048
    desired_count        = 3
    max_capacity         = 6
    image                = "javatodev/internet-banking-service-registry:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  },
  api_gateway = {
    name                 = "internet-banking-api-gateway"
    container_port       = 8082
    host_port            = 8082
    cpu                  = 2048
    memory               = 4096
    desired_count        = 3
    max_capacity         = 8
    image                = "javatodev/internet-banking-api-gateway:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = true
  },
  user_service = {
    name                 = "internet-banking-user-service"
    container_port       = 8083
    host_port            = 8083
    cpu                  = 2048
    memory               = 4096
    desired_count        = 3
    max_capacity         = 8
    image                = "javatodev/internet-banking-user-service:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  },
  fund_transfer_service = {
    name                 = "internet-banking-fund-transfer-service"
    container_port       = 8084
    host_port            = 8084
    cpu                  = 2048
    memory               = 4096
    desired_count        = 3
    max_capacity         = 8
    image                = "javatodev/internet-banking-fund-transfer-service:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  },
  utility_payment_service = {
    name                 = "internet-banking-utility-payment-service"
    container_port       = 8085
    host_port            = 8085
    cpu                  = 2048
    memory               = 4096
    desired_count        = 3
    max_capacity         = 8
    image                = "javatodev/internet-banking-utility-payment-service:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  },
  core_banking_service = {
    name                 = "core-banking-service"
    container_port       = 8092
    host_port            = 8092
    cpu                  = 2048
    memory               = 4096
    desired_count        = 3
    max_capacity         = 8
    image                = "javatodev/core-banking-service:latest"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  },
  keycloak = {
    name                 = "keycloak"
    container_port       = 8080
    host_port            = 8080
    cpu                  = 4096
    memory               = 8192
    desired_count        = 3
    max_capacity         = 6
    image                = "quay.io/keycloak/keycloak:23.0.7"
    health_check_path    = "/health/ready"
    requires_public_access = false
  },
  zipkin = {
    name                 = "zipkin"
    container_port       = 9411
    host_port            = 9411
    cpu                  = 1024
    memory               = 2048
    desired_count        = 2
    max_capacity         = 4
    image                = "openzipkin/zipkin:3"
    health_check_path    = "/actuator/health"
    requires_public_access = false
  }
}
