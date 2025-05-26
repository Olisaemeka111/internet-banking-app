# Internet Banking Infrastructure Module
# This module includes all the submodules for the Internet Banking application

# VPC Module
module "vpc" {
  source = "../vpc"
  
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Security Module
module "security" {
  source = "../security"
  
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# RDS Module
module "rds" {
  source = "../rds"
  
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  mysql_sg_id        = module.security.mysql_sg_id
  postgres_sg_id     = module.security.postgres_sg_id
  mysql_db_name      = var.mysql_db_name
  mysql_username     = var.mysql_username
  mysql_password     = var.mysql_password
  postgres_db_name   = var.postgres_db_name
  postgres_username  = var.postgres_username
  postgres_password  = var.postgres_password
  enable_cross_region_backup = false
  backup_kms_key_id  = null
  backup_sns_topic_arn = null
}

# ElastiCache Module
module "elasticache" {
  source = "../elasticache"
  
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  redis_sg_id        = module.security.redis_sg_id
}

# Service Discovery Module
module "service_discovery" {
  source = "../service_discovery"
  
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  services    = var.services
}

# ECS Module
module "ecs" {
  source = "../ecs"
  
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_sg_id          = module.security.ecs_sg_id
  certificate_arn    = var.certificate_arn
  mysql_endpoint     = module.rds.mysql_endpoint
  postgres_endpoint  = module.rds.postgres_endpoint
  redis_endpoint     = module.elasticache.redis_endpoint
  services           = var.services
  aws_region         = var.aws_region
}

# API Gateway Module - Commented out temporarily to allow the rest of the infrastructure to be deployed
# Will be fixed in a separate PR
# module "api_gateway" {
#   source = "../api_gateway"
#   
#   environment       = var.environment
#   vpc_id            = module.vpc.vpc_id
#   public_subnet_ids = module.vpc.public_subnet_ids
#   api_gateway_sg_id = module.security.api_gateway_sg_id
#   ecs_services      = module.ecs.ecs_services
#   nlb_arn           = module.ecs.network_lb_arn
#   
#   # Define API services mapping based on the services variable
#   api_services = {
#     for k, v in var.services : k => {
#       target_url = "${k}.${var.environment}.internal:${v.container_port}"
#     } if v.requires_public_access
#   }
# }

# Route53 Module
module "route53" {
  source = "../route53"
  
  environment         = var.environment
  domain_name         = var.domain_name
  # API Gateway references commented out temporarily
  api_gateway_dns     = null
  api_gateway_zone_id = null
}

# WAF Module
module "waf" {
  source = "../waf"
  
  environment          = var.environment
  api_gateway_stage_arn = "arn:aws:apigateway:${var.aws_region}::/restapis/*/stages/${var.environment}"
  allowed_countries    = var.waf_allowed_countries
}

# Monitoring Module
module "monitoring" {
  source = "../monitoring"
  
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  ecs_cluster_id = module.ecs.ecs_cluster_id
  ecs_services   = module.ecs.ecs_services
  rds_instances  = module.rds.rds_instances
  aws_region     = var.aws_region
}

# CodePipeline Module
module "codepipeline" {
  source = "../codepipeline"
  
  environment           = var.environment
  aws_region            = var.aws_region
  aws_account_id        = var.aws_account_id
  codestar_connection_arn = var.codestar_connection_arn
  repository_id         = var.repository_id
  branch_name           = var.branch_name
  services              = var.services
}

# Security Scanning Module
module "security_scanning" {
  source = "../security_scanning"
  
  environment           = var.environment
  artifacts_bucket_arn  = module.codepipeline.artifacts_bucket_arn
  repository_id         = var.repository_id
  codestar_connection_arn = var.codestar_connection_arn
  branch_name           = var.branch_name
}
