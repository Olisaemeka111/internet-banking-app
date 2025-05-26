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

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Security Module
module "security" {
  source = "./modules/security"
  
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  mysql_sg_id           = module.security.mysql_sg_id
  postgres_sg_id        = module.security.postgres_sg_id
  mysql_db_name         = var.mysql_db_name
  mysql_username        = var.mysql_username
  mysql_password        = var.mysql_password
  postgres_db_name      = var.postgres_db_name
  postgres_username     = var.postgres_username
  postgres_password     = var.postgres_password
  
  # Cross-region backup configuration
  enable_cross_region_backup = var.enable_cross_region_backup
  backup_kms_key_id          = var.backup_kms_key_id
  backup_sns_topic_arn       = var.backup_sns_topic_arn
}

# ElastiCache Module
module "elasticache" {
  source = "./modules/elasticache"
  
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  redis_sg_id        = module.security.redis_sg_id
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  public_subnet_ids     = module.vpc.public_subnet_ids
  ecs_sg_id             = module.security.ecs_sg_id
  mysql_endpoint        = module.rds.mysql_endpoint
  postgres_endpoint     = module.rds.postgres_endpoint
  redis_endpoint        = module.elasticache.redis_endpoint
  services              = var.services
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api_gateway"
  
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  api_gateway_sg_id = module.security.api_gateway_sg_id
  ecs_services      = module.ecs.ecs_services
  nlb_arn           = module.ecs.network_lb_arn
  certificate_arn   = var.certificate_arn
  
  # Define API services mapping based on the services variable
  api_services = {
    for k, v in var.services : k => {
      target_url = "${k}.${var.environment}.internal:${v.container_port}"
    } if v.requires_public_access
  }
}

# Route53 Module
module "route53" {
  source = "./modules/route53"
  
  environment         = var.environment
  domain_name         = var.domain_name
  api_gateway_dns     = module.api_gateway.api_gateway_dns
  api_gateway_zone_id = module.api_gateway.api_gateway_zone_id
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  ecs_cluster_id = module.ecs.ecs_cluster_id
  ecs_services   = module.ecs.ecs_services
  rds_instances  = module.rds.rds_instances
}

# WAF Module
module "waf" {
  source = "./modules/waf"
  
  environment          = var.environment
  api_gateway_stage_arn = "${module.api_gateway.api_gateway_id}/stages/${module.api_gateway.api_gateway_stage_name}"
  allowed_countries    = var.waf_allowed_countries
}

# Service Discovery Module (AWS Cloud Map)
module "service_discovery" {
  source = "./modules/service_discovery"
  
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  services    = var.services
}

# CodePipeline Module
module "codepipeline" {
  source = "./modules/codepipeline"
  
  environment           = var.environment
  aws_region            = var.aws_region
  aws_account_id        = var.aws_account_id
  services              = var.services
  codestar_connection_arn = var.codestar_connection_arn
  repository_id         = var.repository_id
  branch_name           = var.branch_name
}

# Security Scanning Module
module "security_scanning" {
  source = "./modules/security_scanning"
  
  environment           = var.environment
  artifacts_bucket_arn  = module.codepipeline.artifacts_bucket_arn
  repository_id         = var.repository_id
  codestar_connection_arn = var.codestar_connection_arn
  branch_name           = var.branch_name
}
