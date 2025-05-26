resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-internet-banking-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Cluster CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Cluster Memory Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instances.mysql]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "MySQL RDS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instances.postgres]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "PostgreSQL RDS CPU Utilization"
        }
      }
    ]
  })
}

# CloudWatch Alarms for ECS Cluster
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "${var.environment}-ecs-cluster-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ECS cluster CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    ClusterName = var.ecs_cluster_id
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "${var.environment}-ecs-cluster-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ECS cluster memory utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    ClusterName = var.ecs_cluster_id
  }
}

# CloudWatch Alarms for MySQL RDS
resource "aws_cloudwatch_metric_alarm" "mysql_cpu_utilization" {
  alarm_name          = "${var.environment}-mysql-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors MySQL RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instances.mysql
  }
}

resource "aws_cloudwatch_metric_alarm" "mysql_freeable_memory" {
  alarm_name          = "${var.environment}-mysql-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000000000  # 1 GB in bytes
  alarm_description   = "This metric monitors MySQL RDS freeable memory"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instances.mysql
  }
}

# CloudWatch Alarms for PostgreSQL RDS
resource "aws_cloudwatch_metric_alarm" "postgres_cpu_utilization" {
  alarm_name          = "${var.environment}-postgres-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors PostgreSQL RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instances.postgres
  }
}

resource "aws_cloudwatch_metric_alarm" "postgres_freeable_memory" {
  alarm_name          = "${var.environment}-postgres-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000000000  # 1 GB in bytes
  alarm_description   = "This metric monitors PostgreSQL RDS freeable memory"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instances.postgres
  }
}

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-internet-banking-alarms"
  
  tags = {
    Name        = "${var.environment}-internet-banking-alarms"
    Environment = var.environment
  }
}

# Create log groups for each service first
resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = var.ecs_services
  
  name              = "/ecs/${var.environment}/${each.value.name}"
  retention_in_days = 30
  
  tags = {
    Name        = "/ecs/${var.environment}/${each.value.name}"
    Environment = var.environment
    Service     = each.key
  }
}

# CloudWatch Log Metric Filters for Error Logs
resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  for_each = var.ecs_services
  
  name           = "${var.environment}-${each.key}-error-logs"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.service_logs[each.key].name
  
  depends_on = [aws_cloudwatch_log_group.service_logs]
  
  metric_transformation {
    name      = "${each.key}ErrorCount"
    namespace = "InternetBanking/ErrorLogs"
    value     = "1"
  }
}

# CloudWatch Alarms for Error Logs
resource "aws_cloudwatch_metric_alarm" "error_logs" {
  for_each = var.ecs_services
  
  alarm_name          = "${var.environment}-${each.key}-error-logs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "${each.key}ErrorCount"
  namespace           = "InternetBanking/ErrorLogs"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors error logs for ${each.key}"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}
