# CloudWatch Resources - Infrastructure Monitoring
# Log groups for ECS and infrastructure
# Alarms for monitoring infrastructure (ALB, ECS, VPC)

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

# ECS log group for frontend service
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}-frontend-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.app_name}-ecs-logs"
  }
}

# Infrastructure log group (ALB, VPC Flow Logs, etc.)
resource "aws_cloudwatch_log_group" "infrastructure_logs" {
  name              = "/aws/infrastructure/${var.app_name}-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.app_name}-infrastructure-logs"
  }
}

# ============================================================================
# CloudWatch Alarms - Infrastructure
# ============================================================================

# Alarm: ALB Unhealthy Host Count
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.app_name}-alb-unhealthy-hosts-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when ALB has unhealthy targets"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.ecs.arn_suffix
  }

  tags = {
    Name = "${var.app_name}-alb-unhealthy-hosts"
  }
}

# Alarm: ALB Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.app_name}-alb-response-time-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = 2 # 2 seconds
  alarm_description   = "Alert when ALB target response time is slow"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name = "${var.app_name}-alb-response-time"
  }
}

# Alarm: ECS Service CPU Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "${var.app_name}-ecs-cpu-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when ECS service CPU utilization is high"
  alarm_actions       = []

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }

  tags = {
    Name = "${var.app_name}-ecs-cpu"
  }
}

# Alarm: ECS Service Memory Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "${var.app_name}-ecs-memory-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when ECS service memory utilization is high"
  alarm_actions       = []

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }

  tags = {
    Name = "${var.app_name}-ecs-memory"
  }
}

# ============================================================================
# Backend Monitoring (SAM-Managed)
# ============================================================================
# CloudWatch alarms for Lambda and DynamoDB are configured in backend/template.yaml
# and managed by AWS SAM. These include:
# - Lambda error rates and duration
# - Lambda throttling
# - DynamoDB read/write throttling
# - Bedrock rate limiting
#
# To monitor backend:
#   aws cloudformation describe-stack-resource-summaries \
#     --stack-name hojadevida-backend-{env} \
#     --region us-east-1
