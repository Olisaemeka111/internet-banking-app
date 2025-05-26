output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "mysql_endpoint" {
  description = "Endpoint of the MySQL database"
  value       = module.rds.mysql_endpoint
}

output "postgres_endpoint" {
  description = "Endpoint of the PostgreSQL database"
  value       = module.rds.postgres_endpoint
}

output "redis_endpoint" {
  description = "Endpoint of the Redis cache"
  value       = module.elasticache.redis_endpoint
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs.ecs_cluster_id
}

output "security_reports_bucket" {
  description = "Name of the S3 bucket containing security reports"
  value       = module.security_scanning.security_reports_bucket
}
