variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "mysql_db_name" {
  description = "Name of the MySQL database"
  type        = string
}

variable "mysql_username" {
  description = "Username for MySQL database"
  type        = string
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
}

variable "postgres_username" {
  description = "Username for PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = null
}

variable "waf_allowed_countries" {
  description = "List of allowed country codes for geo restriction"
  type        = list(string)
  default     = ["US", "CA", "GB"]
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
}
