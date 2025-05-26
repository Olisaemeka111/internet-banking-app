resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.environment}-redis-params"
  family = "redis6.x"
  
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = "${var.environment}-internet-banking-redis"
  description                   = "Redis cluster for Internet Banking application"
  node_type                     = "cache.t3.medium"
  port                          = 6379
  parameter_group_name          = aws_elasticache_parameter_group.redis.name
  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [var.redis_sg_id]
  automatic_failover_enabled    = var.environment == "prod" ? true : false
  multi_az_enabled              = var.environment == "prod" ? true : false
  engine                        = "redis"
  engine_version                = "6.2"
  
  num_cache_clusters            = var.environment == "prod" ? 2 : 1
  
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  
  maintenance_window            = "mon:05:00-mon:06:00"
  snapshot_window               = "06:00-07:00"
  snapshot_retention_limit      = var.environment == "prod" ? 7 : 1
  
  tags = {
    Name = "${var.environment}-internet-banking-redis"
  }
}
