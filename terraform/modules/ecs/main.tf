resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-internet-banking-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name = "${var.environment}-internet-banking-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.environment}-ecs-task-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM role for ECS tasks
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment}-ecs-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${var.environment}-ecs-task-policy"
  description = "Policy for ECS tasks"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# CloudWatch log groups for each service
resource "aws_cloudwatch_log_group" "ecs_services" {
  for_each = var.services
  
  name              = "/ecs/${var.environment}/${each.value.name}"
  retention_in_days = 30
  
  tags = {
    Name        = "/ecs/${var.environment}/${each.value.name}"
    Service     = each.value.name
    Environment = var.environment
  }
}

# Network Load Balancer for API Gateway VPC Link
resource "aws_lb" "network" {
  name               = "${var.environment}-network-lb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  
  enable_deletion_protection = var.environment == "prod" ? true : false
  
  tags = {
    Name        = "${var.environment}-network-lb"
    Environment = var.environment
  }
}

# Application Load Balancer for public services
resource "aws_lb" "public" {
  name               = "${var.environment}-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.ecs_sg_id]
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection = var.environment == "prod" ? true : false
  
  tags = {
    Name = "${var.environment}-public-alb"
  }
}

# Internal Load Balancer for private services
resource "aws_lb" "internal" {
  name               = "${var.environment}-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.ecs_sg_id]
  subnets            = var.private_subnet_ids
  
  enable_deletion_protection = var.environment == "prod" ? true : false
  
  tags = {
    Name = "${var.environment}-internal-alb"
  }
}

# Create target groups, listeners, and ECS services for each service
locals {
  public_services  = {for k, v in var.services : k => v if v.requires_public_access}
  private_services = {for k, v in var.services : k => v if !v.requires_public_access}
}

# Target groups for public services
resource "aws_lb_target_group" "public" {
  for_each = local.public_services
  
  name        = "${var.environment}-${replace(each.key, "_", "-")}-tg"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  
  health_check {
    enabled             = true
    interval            = 30
    path                = each.value.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
  
  tags = {
    Name = "${var.environment}-${each.value.name}-tg"
  }
}

# Target groups for private services
resource "aws_lb_target_group" "private" {
  for_each = local.private_services
  
  name        = "${var.environment}-${replace(each.key, "_", "-")}-tg"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  
  health_check {
    enabled             = true
    interval            = 30
    path                = each.value.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
  
  tags = {
    Name = "${var.environment}-${each.value.name}-tg"
  }
}

# Listener for public ALB (HTTPS)
resource "aws_lb_listener" "public_https" {
  count = var.certificate_arn != null ? 1 : 0
  
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Listener for public ALB (HTTP to HTTPS redirect)
resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type = "redirect"
    
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener for internal ALB
resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Listener rules for public services
resource "aws_lb_listener_rule" "public" {
  for_each = local.public_services
  
  listener_arn = var.certificate_arn != null ? aws_lb_listener.public_https[0].arn : aws_lb_listener.public_http.arn
  priority     = 100 + index(keys(local.public_services), each.key)
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public[each.key].arn
  }
  
  condition {
    path_pattern {
      values = ["/${each.key}/*"]
    }
  }
}

# Listener rules for private services
resource "aws_lb_listener_rule" "private" {
  for_each = local.private_services
  
  listener_arn = aws_lb_listener.internal.arn
  priority     = 100 + index(keys(local.private_services), each.key)
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private[each.key].arn
  }
  
  condition {
    path_pattern {
      values = ["/${each.key}/*"]
    }
  }
}

# ECS task definitions and services for each service
resource "aws_ecs_task_definition" "services" {
  for_each = var.services
  
  family                   = "${var.environment}-${each.value.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  
  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = each.value.image
      essential = true
      
      portMappings = [
        {
          containerPort = each.value.container_port
          hostPort      = each.value.host_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.environment
        },
        {
          name  = "MYSQL_HOST"
          value = var.mysql_endpoint
        },
        {
          name  = "POSTGRES_HOST"
          value = var.postgres_endpoint
        },
        {
          name  = "REDIS_HOST"
          value = var.redis_endpoint
        },
        {
          name  = "EUREKA_CLIENT_SERVICEURL_DEFAULTZONE"
          value = "http://dev-internet-banking-service-registry.internal:8081/eureka/"
        },
        {
          name  = "SPRING_CLOUD_CONFIG_URI"
          value = "http://dev-internet-banking-config-server.internal:8090"
        },
        {
          name  = "SPRING_ZIPKIN_BASEURL"
          value = "http://dev-zipkin.internal:9411"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  
  tags = {
    Name = "${var.environment}-${each.value.name}-task"
  }
}

# ECS services for public services
resource "aws_ecs_service" "public" {
  for_each = local.public_services
  
  # Ensure the load balancer and listener rules are created before the ECS service
  depends_on = [
    aws_lb.public,
    aws_lb_listener.public_http,
    aws_lb_listener_rule.public
  ]
  
  name            = "${var.environment}-${each.value.name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  launch_type     = "FARGATE"
  
  desired_count                      = each.value.desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 300
  
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }
  
  # Ensure proper load balancer configuration
  load_balancer {
    target_group_arn = aws_lb_target_group.public[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.container_port
  }
  
  lifecycle {
    ignore_changes = [desired_count]
  }
  
  tags = {
    Name = "${var.environment}-${each.value.name}-service"
  }
}

# ECS services for private services
resource "aws_ecs_service" "private" {
  for_each = local.private_services
  
  name            = "${var.environment}-${each.value.name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  launch_type     = "FARGATE"
  
  desired_count                      = each.value.desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 300
  
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.private[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.container_port
  }
  
  lifecycle {
    ignore_changes = [desired_count]
  }
  
  tags = {
    Name = "${var.environment}-${each.value.name}-service"
  }
}

# Auto Scaling for ECS services
resource "aws_appautoscaling_target" "ecs_target" {
  for_each = var.services
  
  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${each.value.requires_public_access ? aws_ecs_service.public[each.key].name : aws_ecs_service.private[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  for_each = var.services
  
  name               = "${var.environment}-${each.value.name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}
