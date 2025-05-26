variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "services" {
  description = "Map of services to create pipelines for"
  type        = map(object({
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

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub/BitBucket"
  type        = string
}

variable "repository_id" {
  description = "Repository ID in the format 'owner/repo'"
  type        = string
}

variable "branch_name" {
  description = "Branch name to use for the source code"
  type        = string
  default     = "main"
}
