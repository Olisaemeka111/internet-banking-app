variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "internetbanking-example.com"
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = null
}

variable "waf_allowed_countries" {
  description = "List of allowed country codes for WAF geo restriction"
  type        = list(string)
  default     = ["US", "CA", "GB", "DE", "FR", "AU"]
}

variable "enable_cross_region_backup" {
  description = "Whether to enable cross-region backup replication for RDS"
  type        = bool
  default     = false
}

variable "backup_kms_key_id" {
  description = "KMS key ID for cross-region backup encryption"
  type        = string
  default     = null
}

variable "backup_sns_topic_arn" {
  description = "SNS topic ARN for backup event notifications"
  type        = string
  default     = null
}

variable "mysql_db_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "banking_core"
}

variable "mysql_username" {
  description = "Username for MySQL database"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "mysql_password" {
  description = "Password for MySQL database"
  type        = string
  sensitive   = true
}

variable "postgres_db_name" {
  description = "Name of the PostgreSQL database for Keycloak"
  type        = string
  default     = "keycloak"
}

variable "postgres_username" {
  description = "Username for PostgreSQL database"
  type        = string
  default     = "keycloak"
  sensitive   = true
}

variable "postgres_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub/BitBucket"
  type        = string
}

variable "repository_id" {
  description = "Repository ID in the format 'owner/repo'"
  type        = string
}

variable "branch_name" {
  description = "Branch name to use for the source code"
  type        = string
  default     = "main"
}

variable "services" {
  description = "Map of services to deploy"
  type = map(object({
    name                 = string
    container_port       = number
    host_port            = number
    cpu                  = number
    memory               = number
    desired_count        = number
    max_capacity         = number
    image                = string
    health_check_path    = string
    requires_public_access = bool
  }))
  default = {
    config_server = {
      name                 = "internet-banking-config-server"
      container_port       = 8090
      host_port            = 8090
      cpu                  = 512
      memory               = 1024
      desired_count        = 2
      max_capacity         = 4
      image                = "javatodev/internet-banking-config-server:latest"
      health_check_path    = "/actuator/health"
      requires_public_access = false
    },
    service_registry = {
      name                 = "internet-banking-service-registry"
      container_port       = 8081
      host_port            = 8081
      cpu                  = 512
      memory               = 1024
      desired_count        = 2
      max_capacity         = 4
      image                = "javatodev/internet-banking-service-registry:latest"
      health_check_path    = "/actuator/health"
      requires_public_access = false
    },
    api_gateway = {
      name                 = "internet-banking-api-gateway"
      container_port       = 8082
      host_port            = 8082
      cpu                  = 1024
      memory               = 2048
      desired_count        = 2
      max_capacity         = 6
      image                = "javatodev/internet-banking-api-gateway:latest"
      health_check_path    = "/actuator/health"
      requires_public_access = true
    },
    user_service = {
      name                 = "internet-banking-user-service"
      container_port       = 8083
      host_port            = 8083
      cpu                  = 1024
      memory               = 2048
      desired_count        = 2
      max_capacity         = 6
      image                = "javatodev/internet-banking-user-service:latest"
      health_check_path    = "/actuator/health"
      requires_public_access = false
    },
    fund_transfer_service = {
      name                 = "internet-banking-fund-transfer-service"
      container_port       = 8084
      host_port            = 8084
      cpu                  = 1024
      memory               = 2048
      desired_count        = 2
      max_capacity         = 6
      image                = "javatodev/internet-banking-fund-transfer-service:latest"
      health_check_path    = "/actuator/health"
      requires_public_access = false
    },
    utility_payment_service = {
      name                 = "internet-banking-utility-payment-service"
      container_port       = 8085
      host_port            = 8085
      cpu                  = 1024
      memory               = 2048
      desired_count        = 2
      max_capacity         = 6
      image                = "javatodev/internet-banking-utility-payment-service:latest"
      health_check_path    = "/actuator/health"
      requires_public_access = false
    },
    core_banking_service = {
      name                 = "core-banking-service"
      container_port       = 8092
      host_port            = 8092
      cpu                  = 1024
      memory               = 2048
      desired_count        = 2
      max_capacity         = 6
      image                = "javatodev/core-banking-service:latest"
      health_check_path    = "/actuator/health"
      requires_public_access = false
    },
    keycloak = {
      name                 = "keycloak"
      container_port       = 8080
      host_port            = 8080
      cpu                  = 2048
      memory               = 4096
      desired_count        = 2
      max_capacity         = 4
      image                = "quay.io/keycloak/keycloak:23.0.7"
      health_check_path    = "/health/ready"
      requires_public_access = false
    },
    zipkin = {
      name                 = "zipkin"
      container_port       = 9411
      host_port            = 9411
      cpu                  = 512
      memory               = 1024
      desired_count        = 1
      max_capacity         = 2
      image                = "openzipkin/zipkin:3"
      health_check_path    = "/actuator/health"
      requires_public_access = false
    }
  }
}
