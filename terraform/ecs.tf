# ECS Cluster and Task Definition
# Migrated from infrastructure/frontend-setup.yaml (CloudFormation)

# ECS Cluster with Fargate and Fargate Spot capacity providers
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# ECS Capacity Providers (Fargate and Fargate Spot for cost optimization)
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1 # Always keep at least 1 task on FARGATE
    weight            = 100
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    weight            = 100 # Additional tasks on FARGATE_SPOT
    capacity_provider = "FARGATE_SPOT"
  }
}

# ECS Task Definition for frontend
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.app_name}-frontend-task"
  network_mode             = "awsvpc" # REQUIRED for Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_container_cpu
  memory                   = var.ecs_container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.ecs_task_image_uri != null ? var.ecs_task_image_uri : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${var.app_name}-frontend:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.ecs_task_port
          hostPort      = var.ecs_task_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment == "prod" ? "production" : "development"
        },
        {
          name  = "NEXT_PUBLIC_API_URL"
          value = aws_apigatewayv2_api.http_api.api_endpoint
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_USER_POOL_ID"
          value = aws_cognito_user_pool.main.id
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_CLIENT_ID"
          value = aws_cognito_user_pool_client.web.id
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_REGION"
          value = data.aws_region.current.name
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.app_name}-frontend-task"
  }
}

# ECS Service
resource "aws_ecs_service" "frontend" {
  name                              = "${var.app_name}-frontend-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.frontend.arn
  desired_count                     = var.ecs_desired_count
  launch_type                       = "FARGATE"
  scheduling_strategy               = "REPLICA"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false # Private subnets, access via ALB
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "frontend"
    container_port   = var.ecs_task_port
  }

  # Ensure ALB is ready before deploying service
  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_iam_role_policy.ecs_task_role_policy
  ]

  tags = {
    Name = "${var.app_name}-frontend-service"
  }
}

# Optional: Auto-scaling for ECS service
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.ecs_desired_count * 2
  min_capacity       = var.ecs_desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "${var.app_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "${var.app_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}
