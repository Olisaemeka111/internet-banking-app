output "codepipeline_arns" {
  description = "ARNs of the created CodePipelines"
  value       = { for k, v in aws_codepipeline.service_pipelines : k => v.arn }
}

output "ecr_repository_urls" {
  description = "URLs of the created ECR repositories"
  value       = { for k, v in aws_ecr_repository.service_repositories : k => v.repository_url }
}

output "artifacts_bucket" {
  description = "S3 bucket used for artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket used for artifacts"
  value       = aws_s3_bucket.artifacts.arn
}
