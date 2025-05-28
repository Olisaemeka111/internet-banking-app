resource "aws_db_instance" "mysql" {
  identifier           = "${var.project_name}-${var.environment}-mysql"
  allocated_storage    = var.allocated_storage
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.instance_class
  name                 = var.database_name
  username             = var.database_user
  password             = var.database_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-mysql-final-snapshot"
  vpc_security_group_ids = [var.mysql_sg_id]
  db_subnet_group_name = aws_db_subnet_group.mysql.name
  backup_retention_period = 7
  backup_window = "03:00-05:00"
  maintenance_window = "Mon:00:00-Mon:03:00"
  multi_az = true
  storage_encrypted = true
  kms_key_id = aws_kms_key.rds_encryption_key.arn
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  deletion_protection = true
  apply_immediately = false
  auto_minor_version_upgrade = true
  publicly_accessible = false
  copy_tags_to_snapshot = true
  tags = {
    Name = "${var.project_name}-${var.environment}-mysql"
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "mysql" {
  name       = "${var.project_name}-${var.environment}-mysql-subnet-group"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "${var.project_name}-${var.environment}-mysql-subnet-group"
    Environment = var.environment
  }
}

resource "aws_kms_key" "rds_encryption_key" {
  description = "KMS key for RDS encryption"
  enable_key_rotation = true
  deletion_window_in_days = 30
  tags = {
    Name = "${var.project_name}-${var.environment}-rds-kms-key"
    Environment = var.environment
  }
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "key-default-1",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.account_id}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow RDS to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "monitoring.rds.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
