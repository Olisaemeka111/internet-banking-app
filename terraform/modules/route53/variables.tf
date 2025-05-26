variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "api_gateway_dns" {
  description = "Custom domain name for the API Gateway"
  type        = string
  default     = null
}

variable "api_gateway_zone_id" {
  description = "Route 53 zone ID for the API Gateway custom domain"
  type        = string
  default     = null
}
