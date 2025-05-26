# Cross-region backup configuration for MySQL
resource "aws_db_instance_automated_backups_replication" "mysql_backup_replication" {
  count                  = var.environment == "prod" && var.enable_cross_region_backup ? 1 : 0
  source_db_instance_arn = aws_db_instance.mysql.arn
  retention_period       = 7
  kms_key_id             = var.backup_kms_key_id
}

# Cross-region backup configuration for PostgreSQL
resource "aws_db_instance_automated_backups_replication" "postgres_backup_replication" {
  count                  = var.environment == "prod" && var.enable_cross_region_backup ? 1 : 0
  source_db_instance_arn = aws_db_instance.postgres.arn
  retention_period       = 7
  kms_key_id             = var.backup_kms_key_id
}

# Backup event subscription for MySQL
resource "aws_db_event_subscription" "mysql_backup_events" {
  count     = var.environment == "prod" && var.enable_cross_region_backup ? 1 : 0
  name      = "${var.environment}-mysql-backup-events"
  sns_topic = var.backup_sns_topic_arn
  
  source_type = "db-instance"
  source_ids  = [aws_db_instance.mysql.id]
  
  event_categories = [
    "backup",
    "recovery"
  ]
  
  tags = {
    Name        = "${var.environment}-mysql-backup-events"
    Environment = var.environment
  }
}

# Backup event subscription for PostgreSQL
resource "aws_db_event_subscription" "postgres_backup_events" {
  count     = var.environment == "prod" && var.enable_cross_region_backup ? 1 : 0
  name      = "${var.environment}-postgres-backup-events"
  sns_topic = var.backup_sns_topic_arn
  
  source_type = "db-instance"
  source_ids  = [aws_db_instance.postgres.id]
  
  event_categories = [
    "backup",
    "recovery"
  ]
  
  tags = {
    Name        = "${var.environment}-postgres-backup-events"
    Environment = var.environment
  }
}
