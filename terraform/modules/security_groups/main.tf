resource "aws_security_group" "api_gateway_sg" {
  name        = "${var.project_name}-${var.environment}-api-gateway-sg"
  description = "Security group for API Gateway"
  vpc_id      = var.vpc_id

  # Allow HTTPS from load balancer
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description = "Allow HTTPS from ALB"
  }

  # Allow HTTP from load balancer (for redirects)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description = "Allow HTTP from ALB"
  }

  # Egress rule: allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api-gateway-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # Allow HTTPS from internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Allow HTTPS from allowed CIDRs"
  }

  # Allow HTTP from internet (for redirects)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Allow HTTP from allowed CIDRs"
  }

  # Egress rule: allow all traffic to API Gateway
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "microservices_sg" {
  name        = "${var.project_name}-${var.environment}-microservices-sg"
  description = "Security group for microservices"
  vpc_id      = var.vpc_id

  # Allow traffic from API Gateway
  ingress {
    from_port   = 8080
    to_port     = 8099
    protocol    = "tcp"
    security_groups = [aws_security_group.api_gateway_sg.id]
    description = "Allow API traffic from API Gateway"
  }

  # Allow internal communication between microservices
  ingress {
    from_port   = 8080
    to_port     = 8099
    protocol    = "tcp"
    self        = true
    description = "Allow internal microservices communication"
  }

  # Egress rule: allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-microservices-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group for database"
  vpc_id      = var.vpc_id

  # Allow MySQL traffic from microservices
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.microservices_sg.id]
    description = "Allow MySQL from microservices"
  }

  # Allow PostgreSQL traffic from microservices (for Keycloak)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.microservices_sg.id]
    description = "Allow PostgreSQL from microservices"
  }

  # No direct outbound access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-db-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "bastion_sg" {
  count       = var.create_bastion ? 1 : 0
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # Allow SSH from specific IPs
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_ips
    description = "Allow SSH from specific IPs"
  }

  # Egress rule: allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
    Environment = var.environment
  }
}
