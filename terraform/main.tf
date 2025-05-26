terraform {
  required_version = ">= 1.0.0"
  
  backend "s3" {
    # This will be configured per environment
    # Example: bucket = "internet-banking-terraform-state"
    # key    = "terraform.tfstate"
    # region = "us-east-1"
    # encrypt = true
    # dynamodb_table = "terraform-lock"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "Internet-Banking"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Internet Banking Infrastructure Module
module "internet_banking" {
  source = "./modules/internet_banking"
  
  # Pass all variables to the module
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  mysql_db_name       = var.mysql_db_name
  mysql_username      = var.mysql_username
  mysql_password      = var.mysql_password
  postgres_db_name    = var.postgres_db_name
  postgres_username   = var.postgres_username
  postgres_password   = var.postgres_password
  domain_name         = var.domain_name
  certificate_arn     = var.certificate_arn
  waf_allowed_countries = var.waf_allowed_countries
  aws_account_id      = var.aws_account_id
  codestar_connection_arn = var.codestar_connection_arn
  repository_id       = var.repository_id
  branch_name         = var.branch_name
  services            = var.services
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.internet_banking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.internet_banking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.internet_banking.private_subnet_ids
}

output "mysql_endpoint" {
  description = "Endpoint of the MySQL database"
  value       = module.internet_banking.mysql_endpoint
}

output "postgres_endpoint" {
  description = "Endpoint of the PostgreSQL database"
  value       = module.internet_banking.postgres_endpoint
}

output "redis_endpoint" {
  description = "Endpoint of the Redis cache"
  value       = module.internet_banking.redis_endpoint
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.internet_banking.ecs_cluster_name
}

output "security_reports_bucket" {
  description = "Name of the S3 bucket containing security reports"
  value       = module.internet_banking.security_reports_bucket
}
