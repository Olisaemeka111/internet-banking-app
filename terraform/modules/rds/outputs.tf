output "mysql_endpoint" {
  description = "The connection endpoint for the MySQL database"
  value       = aws_db_instance.mysql.endpoint
}

output "mysql_address" {
  description = "The hostname of the MySQL instance"
  value       = aws_db_instance.mysql.address
}

output "postgres_endpoint" {
  description = "The connection endpoint for the PostgreSQL database"
  value       = aws_db_instance.postgres.endpoint
}

output "postgres_address" {
  description = "The hostname of the PostgreSQL instance"
  value       = aws_db_instance.postgres.address
}

output "rds_instances" {
  description = "Map of RDS instances for monitoring"
  value = {
    mysql    = aws_db_instance.mysql.id
    postgres = aws_db_instance.postgres.id
  }
}
