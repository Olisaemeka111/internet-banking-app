# Additional IAM policies for ECS tasks and execution roles

# Enhanced policy for ECS task execution role
resource "aws_iam_policy" "ecs_task_execution_enhanced_policy" {
  name        = "${var.environment}-ecs-task-execution-enhanced-policy"
  description = "Enhanced policy for ECS task execution role to pull images from ECR and write logs to CloudWatch"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the enhanced policy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_enhanced_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_enhanced_policy.arn
}

# Enhanced policy for ECS task role
resource "aws_iam_policy" "ecs_task_enhanced_policy" {
  name        = "${var.environment}-ecs-task-enhanced-policy"
  description = "Enhanced policy for ECS task role with additional permissions"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the enhanced policy to the ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_enhanced_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_enhanced_policy.arn
}
