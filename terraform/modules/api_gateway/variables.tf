variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "api_gateway_sg_id" {
  description = "ID of the API Gateway security group"
  type        = string
}

variable "ecs_services" {
  description = "Map of ECS services"
  type        = map(any)
}

variable "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  type        = string
}

variable "api_services" {
  description = "Map of API services to expose through API Gateway"
  type        = map(object({
    target_url = string
  }))
}

variable "domain_name" {
  description = "Domain name for the API Gateway"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = null
}
