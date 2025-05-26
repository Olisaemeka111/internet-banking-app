resource "aws_s3_bucket" "security_reports" {
  bucket = "${var.environment}-internet-banking-security-reports"
}

resource "aws_s3_bucket_versioning" "security_reports_versioning" {
  bucket = aws_s3_bucket.security_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "security_reports_lifecycle" {
  bucket = aws_s3_bucket.security_reports.id

  rule {
    id     = "delete-old-reports"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_iam_role" "security_scan_role" {
  name = "${var.environment}-internet-banking-security-scan-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "security_scan_policy" {
  name = "${var.environment}-internet-banking-security-scan-policy"
  role = aws_iam_role.security_scan_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.security_reports.arn,
          "${aws_s3_bucket.security_reports.arn}/*",
          "${var.artifacts_bucket_arn}",
          "${var.artifacts_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_codebuild_project" "security_scan" {
  name          = "${var.environment}-internet-banking-security-scan"
  description   = "Security scanning for Terraform code using tfsec and checkov"
  build_timeout = "30"
  service_role  = aws_iam_role.security_scan_role.arn

  artifacts {
    type = "S3"
    location = aws_s3_bucket.security_reports.bucket
    name = "security-reports"
    packaging = "ZIP"
    path = "reports"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type      = "S3"
    location  = "${var.artifacts_bucket_arn}/source.zip"
    buildspec = "terraform/security-buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.environment}-internet-banking-security-scan"
      stream_name = "build-log"
    }
  }

  tags = {
    Environment = var.environment
  }
}
