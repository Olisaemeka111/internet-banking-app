variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "api_gateway_stage_arn" {
  description = "ARN of the API Gateway stage to associate with WAF"
  type        = string
}

variable "allowed_countries" {
  description = "List of allowed country codes for geo restriction (optional)"
  type        = list(string)
  default     = ["US", "CA", "GB", "DE", "FR", "AU"]
}
