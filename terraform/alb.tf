# Application Load Balancer (ALB) Resources
# Migrated from infrastructure/frontend-setup.yaml (CloudFormation)

resource "aws_lb" "main" {
  name_prefix        = substr(replace(var.app_name, "-", ""), 0, 6) # ALB names must be 1-32 chars
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = var.alb_enable_deletion_protection

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# Target Group for ECS tasks
resource "aws_lb_target_group" "ecs" {
  name_prefix          = substr(replace(var.app_name, "-", ""), 0, 6)
  port                 = var.ecs_task_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "ip" # REQUIRED for Fargate
  deregistration_delay = 30

  health_check {
    path                = "/" # Frontend serves at root
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399" # Accept 2xx and 3xx status codes
  }

  tags = {
    Name = "${var.app_name}-tg"
  }
}

# HTTP Listener for ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}

# HTTPS Listener (optional, production)
resource "aws_lb_listener" "https" {
  count             = var.enable_https_alb ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "" # TODO: Add ACM certificate ARN in production

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}
