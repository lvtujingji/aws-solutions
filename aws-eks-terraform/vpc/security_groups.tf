# =============================================================================
# 1. ALB Security Group
# =============================================================================

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-sg-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-alb-sg"
      Environment = var.environment
      Type        = "ALB"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Ingress - HTTP
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  tags = {
    Name = "alb-http-ingress"
  }
}

# ALB Ingress - HTTPS
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "alb-https-ingress"
  }
}

# ALB Egress - All traffic
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "alb-all-egress"
  }
}

# =============================================================================
# 2. Application Security Group
# =============================================================================

resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-app-sg-"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-app-sg"
      Environment = var.environment
      Type        = "Application"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# App Ingress - From ALB
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  for_each = toset([for port in var.app_ports : tostring(port)])

  security_group_id = aws_security_group.app.id
  description       = "Allow traffic from ALB on port ${each.value}"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  ip_protocol                  = "tcp"

  tags = {
    Name = "app-from-alb-${each.value}"
  }
}

# App Ingress - SSH (从堡垒机或VPN)
resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id = aws_security_group.app.id
  description       = "Allow SSH from VPC"

  cidr_ipv4   = var.vpc_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  tags = {
    Name = "app-ssh-ingress"
  }
}

# App Egress - All traffic
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "app-all-egress"
  }
}

# =============================================================================
# 3. RDS Security Group
# =============================================================================

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-sg-"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-rds-sg"
      Environment = var.environment
      Type        = "Database"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Ingress - From Application
resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow MySQL/Aurora from application"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"

  tags = {
    Name = "rds-from-app"
  }
}

# RDS Egress - Not needed typically, but added for completeness
resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "rds-all-egress"
  }
}

# =============================================================================
# 4. Redis/ElastiCache Security Group
# =============================================================================

resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-sg-"
  description = "Security group for Redis/ElastiCache"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redis-sg"
      Environment = var.environment
      Type        = "Cache"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Redis Ingress - From Application
resource "aws_vpc_security_group_ingress_rule" "redis_from_app" {
  security_group_id = aws_security_group.redis.id
  description       = "Allow Redis from application"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"

  tags = {
    Name = "redis-from-app"
  }
}

# Redis Egress
resource "aws_vpc_security_group_egress_rule" "redis_all" {
  security_group_id = aws_security_group.redis.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "redis-all-egress"
  }
}

