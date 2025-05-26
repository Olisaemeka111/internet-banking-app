output "redis_endpoint" {
  description = "The primary endpoint for the Redis cluster"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "The reader endpoint for the Redis cluster"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}
