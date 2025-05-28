# IAM Policies for CodePipeline and ECS Deployment

# ECS Deployment Action Policy
resource "aws_iam_policy" "ecs_deploy_action_policy" {
  name        = "${var.environment}-ecs-deploy-action-policy"
  description = "Policy for ECS deployment actions in CodePipeline"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-ecs-task-role",
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-ecs-task-execution-role"
        ]
      }
    ]
  })
}

# CodePipeline ECS Deployment Policy
resource "aws_iam_policy" "codepipeline_ecs_deployment_policy" {
  name        = "${var.environment}-codepipeline-ecs-deployment-policy"
  description = "Policy for CodePipeline to deploy to ECS"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:CreateService",
          "ecs:DeleteService",
          "ecs:ListServices",
          "ecs:ListTaskDefinitions",
          "ecs:ListClusters",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeClusters",
          "ecs:CreateTaskSet",
          "ecs:UpdateTaskSet",
          "ecs:DeleteTaskSet",
          "ecs:UpdateClusterSettings",
          "ecs:PutClusterCapacityProviders"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policies to the CodePipeline role
resource "aws_iam_role_policy_attachment" "codepipeline_ecs_deploy_action" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.ecs_deploy_action_policy.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecs_deployment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_ecs_deployment_policy.arn
}

# Attach the AWS managed ECS full access policy
resource "aws_iam_role_policy_attachment" "codepipeline_ecs_full_access" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}
