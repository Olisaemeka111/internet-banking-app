variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "mysql_sg_id" {
  description = "ID of the MySQL security group"
  type        = string
}

variable "postgres_sg_id" {
  description = "ID of the PostgreSQL security group"
  type        = string
}

variable "mysql_db_name" {
  description = "Name of the MySQL database"
  type        = string
}

variable "mysql_username" {
  description = "Username for MySQL database"
  type        = string
  sensitive   = true
}

variable "mysql_password" {
  description = "Password for MySQL database"
  type        = string
  sensitive   = true
}

variable "postgres_db_name" {
  description = "Name of the PostgreSQL database for Keycloak"
  type        = string
}

variable "postgres_username" {
  description = "Username for PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "enable_cross_region_backup" {
  description = "Whether to enable cross-region backup replication"
  type        = bool
  default     = false
}

variable "backup_kms_key_id" {
  description = "KMS key ID for cross-region backup encryption"
  type        = string
  default     = null
}

variable "backup_sns_topic_arn" {
  description = "SNS topic ARN for backup event notifications"
  type        = string
  default     = null
}
