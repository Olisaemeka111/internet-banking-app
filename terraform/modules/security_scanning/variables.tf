variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket used for storing artifacts"
  type        = string
}

variable "repository_id" {
  description = "Repository ID in the format 'owner/repo'"
  type        = string
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub/BitBucket"
  type        = string
}

variable "branch_name" {
  description = "Branch name to use for the source code"
  type        = string
  default     = "main"
}
