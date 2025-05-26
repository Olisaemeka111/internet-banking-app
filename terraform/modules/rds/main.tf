# MySQL RDS Instance for core banking services
resource "aws_db_subnet_group" "mysql" {
  name       = "${var.environment}-mysql-subnet-group"
  subnet_ids = var.private_subnet_ids
  
  tags = {
    Name = "${var.environment}-mysql-subnet-group"
  }
}

resource "aws_db_parameter_group" "mysql" {
  name   = "${var.environment}-mysql-params"
  family = "mysql8.0"
  
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
  
  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.environment}-banking-core-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.medium"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp2"
  storage_encrypted      = true
  
  db_name                = var.mysql_db_name
  username               = var.mysql_username
  password               = var.mysql_password
  
  vpc_security_group_ids = [var.mysql_sg_id]
  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  parameter_group_name   = aws_db_parameter_group.mysql.name
  
  multi_az               = var.environment == "prod" ? true : false
  publicly_accessible    = false
  skip_final_snapshot    = var.environment != "prod"
  deletion_protection    = var.environment == "prod" ? true : false
  
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  
  tags = {
    Name = "${var.environment}-banking-core-mysql"
  }
}

# PostgreSQL RDS Instance for Keycloak
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.environment}-postgres-subnet-group"
  subnet_ids = var.private_subnet_ids
  
  tags = {
    Name = "${var.environment}-postgres-subnet-group"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${var.environment}-postgres-params"
  family = "postgres15"
  
  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.environment}-keycloak-postgres"
  engine                 = "postgres"
  engine_version         = "15.3"
  instance_class         = "db.t3.medium"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp2"
  storage_encrypted      = true
  
  db_name                = var.postgres_db_name
  username               = var.postgres_username
  password               = var.postgres_password
  
  vpc_security_group_ids = [var.postgres_sg_id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  parameter_group_name   = aws_db_parameter_group.postgres.name
  
  multi_az               = var.environment == "prod" ? true : false
  publicly_accessible    = false
  skip_final_snapshot    = var.environment != "prod"
  deletion_protection    = var.environment == "prod" ? true : false
  
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  tags = {
    Name = "${var.environment}-keycloak-postgres"
  }
}
