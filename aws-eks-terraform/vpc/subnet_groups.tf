# =============================================================================
# RDS Subnet Group
# =============================================================================

resource "aws_db_subnet_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-subnet-group-"
  description = "RDS subnet group for ${var.project_name} ${var.environment}"
  subnet_ids  = aws_subnet.db_private[*].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-rds-subnet-group"
      Environment = var.environment
      Type        = "Database"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# ElastiCache (Redis) Subnet Group
# =============================================================================

resource "aws_elasticache_subnet_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-subnet-group"
  description = "ElastiCache subnet group for ${var.project_name} ${var.environment}"
  subnet_ids  = aws_subnet.db_private[*].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redis-subnet-group"
      Environment = var.environment
      Type        = "Cache"
    }
  )
}

