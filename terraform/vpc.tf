# VPC and Networking Resources
# Migrated from infrastructure/network-setup.yaml (CloudFormation)
# Provides: VPC, subnets (public + private across 2 AZs), IGW, conditional NAT, route tables

# 1. VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.application_name}-vpc"
  }
}

# 2. Internet Gateway (for public subnets)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.application_name}-igw"
  }
}

# 3. Public Subnets (ALB will be here)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.application_name}-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.application_name}-public-subnet-2"
  }
}

# 4. Private Subnets (ECS will be here)
# In production: route via NAT gateways
# In dev: route directly via IGW (cost optimization)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  # Only map public IPs in dev (when NAT is disabled)
  map_public_ip_on_launch = !var.enable_nat_gateway

  tags = {
    Name = "${var.application_name}-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = !var.enable_nat_gateway

  tags = {
    Name = "${var.application_name}-private-subnet-2"
  }
}

# 5. Elastic IPs for NAT Gateways (production only)
resource "aws_eip" "nat_1" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.application_name}-eip-1"
  }
}

resource "aws_eip" "nat_2" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.application_name}-eip-2"
  }
}

# 6. NAT Gateways (production only, one per AZ for HA)
resource "aws_nat_gateway" "nat_1" {
  count         = var.enable_nat_gateway ? 1 : 0
  subnet_id     = aws_subnet.public_1.id
  allocation_id = aws_eip.nat_1[0].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.application_name}-nat-gateway-1"
  }
}

resource "aws_nat_gateway" "nat_2" {
  count         = var.enable_nat_gateway ? 1 : 0
  subnet_id     = aws_subnet.public_2.id
  allocation_id = aws_eip.nat_2[0].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.application_name}-nat-gateway-2"
  }
}

# 7. Route Tables

# Public route table (both public subnets share one)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.application_name}-public-rt"
  }
}

# Public route: 0.0.0.0/0 → IGW
resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Private route tables (one per AZ for HA)
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.application_name}-private-rt-1"
  }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.application_name}-private-rt-2"
  }
}

# Private routes: 0.0.0.0/0 → NAT (if enabled) or IGW (dev)
resource "aws_route" "private_nat_1" {
  route_table_id         = aws_route_table.private_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.enable_nat_gateway ? aws_nat_gateway.nat_1[0].id : null
  gateway_id             = !var.enable_nat_gateway ? aws_internet_gateway.main.id : null

  depends_on = [aws_nat_gateway.nat_1]
}

resource "aws_route" "private_nat_2" {
  route_table_id         = aws_route_table.private_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.enable_nat_gateway ? aws_nat_gateway.nat_2[0].id : null
  gateway_id             = !var.enable_nat_gateway ? aws_internet_gateway.main.id : null

  depends_on = [aws_nat_gateway.nat_2]
}

# 8. Subnet Route Table Associations

# Public subnets → public route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private subnets → private route tables (AZ-specific)
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}

# 9. Security Groups

# ALB Security Group (internet-facing, port 80)
resource "aws_security_group" "alb" {
  name_prefix = "${var.application_name}-alb-"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS in production
  dynamic "ingress" {
    for_each = var.enable_https_alb ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.application_name}-alb-sg"
  }
}

# ECS Security Group (allows inbound from ALB on port 3000)
resource "aws_security_group" "ecs" {
  name_prefix = "${var.application_name}-ecs-"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Inbound from ALB
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow all outbound traffic (for Docker pulls, API calls, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.application_name}-ecs-sg"
  }
}

# Data source: Get available AZs for the region
data "aws_availability_zones" "available" {
  state = "available"
}
