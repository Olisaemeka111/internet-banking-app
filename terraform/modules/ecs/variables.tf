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

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "ID of the ECS security group"
  type        = string
}

variable "mysql_endpoint" {
  description = "The connection endpoint for the MySQL database"
  type        = string
}

variable "postgres_endpoint" {
  description = "The connection endpoint for the PostgreSQL database"
  type        = string
}

variable "redis_endpoint" {
  description = "The primary endpoint for the Redis cluster"
  type        = string
}

variable "services" {
  description = "Map of services to deploy"
  type = map(object({
    name                 = string
    container_port       = number
    host_port            = number
    cpu                  = number
    memory               = number
    desired_count        = number
    max_capacity         = number
    image                = string
    health_check_path    = string
    requires_public_access = bool
  }))
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = null
}

variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
