resource "aws_codepipeline" "security_scan_pipeline" {
  name     = "${var.environment}-internet-banking-security-scan-pipeline"
  role_arn = aws_iam_role.security_scan_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.security_reports.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.repository_id
        BranchName       = var.branch_name
      }
    }
  }

  stage {
    name = "SecurityScan"

    action {
      name             = "TfsecCheckovScan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["security_scan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.security_scan.name
      }
    }
  }

  stage {
    name = "Notify"

    action {
      name            = "SecurityNotification"
      category        = "Invoke"
      owner           = "AWS"
      provider        = "Lambda"
      input_artifacts = ["security_scan_output"]
      version         = "1"

      configuration = {
        FunctionName = aws_lambda_function.security_notification.function_name
      }
    }
  }
}

resource "aws_iam_role" "security_scan_pipeline_role" {
  name = "${var.environment}-internet-banking-security-scan-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "security_scan_pipeline_policy" {
  name = "${var.environment}-internet-banking-security-scan-pipeline-policy"
  role = aws_iam_role.security_scan_pipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.security_reports.arn,
          "${aws_s3_bucket.security_reports.arn}/*"
        ]
      },
      {
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = aws_lambda_function.security_notification.arn
      },
      {
        Action = [
          "codestar-connections:UseConnection"
        ]
        Effect   = "Allow"
        Resource = var.codestar_connection_arn
      }
    ]
  })
}

# Lambda function for security notifications
resource "aws_lambda_function" "security_notification" {
  function_name = "${var.environment}-internet-banking-security-notification"
  role          = aws_iam_role.security_notification_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  timeout       = 30

  filename         = data.archive_file.security_notification_zip.output_path
  source_code_hash = data.archive_file.security_notification_zip.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT = var.environment
      REPORT_BUCKET = aws_s3_bucket.security_reports.bucket
    }
  }
}

data "archive_file" "security_notification_zip" {
  type        = "zip"
  output_path = "${path.module}/security_notification.zip"
  
  source {
    content  = <<EOF
exports.handler = async (event, context) => {
  console.log('Security scan completed');
  console.log('Event:', JSON.stringify(event, null, 2));
  
  // Add notification logic here (e.g., SNS, Slack, etc.)
  
  return {
    statusCode: 200,
    body: JSON.stringify('Security notification sent'),
  };
};
EOF
    filename = "index.js"
  }
}

resource "aws_iam_role" "security_notification_role" {
  name = "${var.environment}-internet-banking-security-notification-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "security_notification_policy" {
  name = "${var.environment}-internet-banking-security-notification-policy"
  role = aws_iam_role.security_notification_role.id

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.security_reports.arn,
          "${aws_s3_bucket.security_reports.arn}/*"
        ]
      }
    ]
  })
}
