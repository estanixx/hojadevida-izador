# CloudWatch Resources
# Log groups for Lambda, API Gateway, and ECS
# Alarms for monitoring Lambda errors and Bedrock throttling

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

# Lambda log group (shared by all Lambda functions)
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.app_name}-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.app_name}-lambda-logs"
  }
}

# ECS log group for frontend service
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}-frontend-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.app_name}-ecs-logs"
  }
}

# ============================================================================
# CloudWatch Alarms
# ============================================================================

# Alarm for Lambda errors (listCvs and generateCv)
resource "aws_cloudwatch_metric_alarm" "lambda_list_cvs_errors" {
  alarm_name          = "${var.app_name}-listCvs-errors-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.lambda_error_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300" # 5 minutes
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_description   = "Alert when listCvs Lambda function has 5+ errors in 5 minutes"
  alarm_actions       = [] # SNS topic would go here for production

  dimensions = {
    FunctionName = aws_lambda_function.list_cvs.function_name
  }

  tags = {
    Name = "${var.app_name}-listCvs-errors"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_generate_cv_errors" {
  alarm_name          = "${var.app_name}-generateCv-errors-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.lambda_error_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300" # 5 minutes
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_description   = "Alert when generateCv Lambda function has 5+ errors in 5 minutes"
  alarm_actions       = [] # SNS topic would go here for production

  dimensions = {
    FunctionName = aws_lambda_function.generate_cv.function_name
  }

  tags = {
    Name = "${var.app_name}-generateCv-errors"
  }
}

# Alarm for Lambda throttling
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.app_name}-lambda-throttles-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when Lambda functions are throttled"
  alarm_actions       = []

  tags = {
    Name = "${var.app_name}-lambda-throttles"
  }
}

# Alarm for Lambda duration (generateCv should complete within 5 minutes)
resource "aws_cloudwatch_metric_alarm" "lambda_generate_cv_duration" {
  alarm_name          = "${var.app_name}-generateCv-duration-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "280000" # 280 seconds (leaving 20 sec buffer for timeout)
  alarm_description   = "Alert when generateCv Lambda takes more than 4.6+ minutes"
  alarm_actions       = []

  dimensions = {
    FunctionName = aws_lambda_function.generate_cv.function_name
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-generateCv-duration"
  }
}

# Alarm for ECS service task count
resource "aws_cloudwatch_metric_alarm" "ecs_task_count" {
  alarm_name          = "${var.app_name}-ecs-task-count-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningCount"
  namespace           = "ECS/ContainerInsights"
  period              = "60"
  statistic           = "Average"
  threshold           = var.ecs_desired_count - 1 # Alert if less than desired - 1
  alarm_description   = "Alert when ECS service has fewer running tasks than desired"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.frontend.name
    ClusterName = aws_ecs_cluster.main.name
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-ecs-task-count"
  }
}

# Alarm for ECS CPU utilization
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "${var.app_name}-ecs-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = var.ecs_container_cpu * 0.8 # Alert at 80% of max CPU
  alarm_description   = "Alert when ECS service CPU utilization is high"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.frontend.name
    ClusterName = aws_ecs_cluster.main.name
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-ecs-cpu-high"
  }
}

# Alarm for ECS memory utilization
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "${var.app_name}-ecs-memory-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = var.ecs_container_memory * 0.8 # Alert at 80% of max memory
  alarm_description   = "Alert when ECS service memory utilization is high"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.frontend.name
    ClusterName = aws_ecs_cluster.main.name
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-ecs-memory-high"
  }
}

# Alarm for ALB unhealthy target count
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.app_name}-alb-unhealthy-targets-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when ALB has unhealthy targets"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.ecs.arn_suffix
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-alb-unhealthy"
  }
}

# Alarm for ALB target response time
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.app_name}-alb-response-time-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = 2 # 2 seconds
  alarm_description   = "Alert when ALB target response time exceeds 2 seconds"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-alb-response-time"
  }
}

# Alarm for DynamoDB read throttling (if using PROVISIONED mode)
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttle" {
  count               = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  alarm_name          = "${var.app_name}-dynamodb-read-throttle-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when DynamoDB read operations are throttled"
  alarm_actions       = []

  dimensions = {
    TableName = aws_dynamodb_table.cvs.name
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-dynamodb-read-throttle"
  }
}

# Alarm for DynamoDB write throttling (if using PROVISIONED mode)
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttle" {
  count               = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  alarm_name          = "${var.app_name}-dynamodb-write-throttle-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when DynamoDB write operations are throttled"
  alarm_actions       = []

  dimensions = {
    TableName = aws_dynamodb_table.cvs.name
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.app_name}-dynamodb-write-throttle"
  }
}

# ============================================================================
# CloudWatch Dashboard (for visual monitoring)
# ============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.app_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Errors" }],
            [".", "Duration", { stat = "Average", label = "Duration (ms)" }],
            [".", "Throttles", { stat = "Sum", label = "Throttles" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Lambda Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average", label = "Response Time" }],
            [".", "RequestCount", { stat = "Sum", label = "Request Count" }],
            [".", "HealthyHostCount", { stat = "Average", label = "Healthy Hosts" }],
            [".", "UnHealthyHostCount", { stat = "Average", label = "Unhealthy Hosts" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "DesiredTaskCount", { stat = "Average", label = "Desired" }],
            [".", "RunningCount", { stat = "Average", label = "Running" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS Task Count"
          dimensions = {
            ServiceName = aws_ecs_service.frontend.name
            ClusterName = aws_ecs_cluster.main.name
          }
        }
      }
    ]
  })
}
