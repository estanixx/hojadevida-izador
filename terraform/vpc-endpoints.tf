# VPC Endpoints for ECR and CloudWatch Logs
# Required for Fargate tasks in private subnets to pull images from ECR
# Without these endpoints, ECS tasks get i/o timeout when pulling Docker images

# Security group for VPC endpoints (allows HTTPS from ECS tasks)
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.application_name}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  # Allow HTTPS from ECS security group
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.application_name}-vpc-endpoints-sg"
  }
}

# ECR API Endpoint (needed for GetAuthorizationToken and pulling images)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.application_name}-ecr-api-endpoint"
  }
}

# ECR DKR Endpoint (needed for actually pulling container images)
# Note: Using wildcard format for service name to ensure compatibility
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.application_name}-ecr-dkr-endpoint"
  }
}

# CloudWatch Logs Endpoint (needed for ECS tasks to stream logs)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.application_name}-logs-endpoint"
  }
}

# S3 Endpoint (gateway-type, more efficient for S3 access from private subnets)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_1.id, aws_route_table.private_2.id]

  tags = {
    Name = "${var.application_name}-s3-endpoint"
  }
}
