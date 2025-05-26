output "security_scan_project_arn" {
  description = "ARN of the security scanning CodeBuild project"
  value       = aws_codebuild_project.security_scan.arn
}

output "security_reports_bucket" {
  description = "Name of the S3 bucket where security reports are stored"
  value       = aws_s3_bucket.security_reports.bucket
}

output "security_reports_bucket_arn" {
  description = "ARN of the S3 bucket where security reports are stored"
  value       = aws_s3_bucket.security_reports.arn
}
