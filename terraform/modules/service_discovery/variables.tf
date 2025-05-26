variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "services" {
  description = "Map of services to create service discovery entries for"
  type        = map(any)
}
