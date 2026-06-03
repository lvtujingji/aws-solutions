# ============================================================================
# Public Subnets (2个) - /24
# =============================================================================

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index) # 192.168.0.0/24 192.168.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-public-subnet-${local.subnet_letters[count.index]}"
      Environment = var.environment
      Type        = "Public"
      Tier        = "Public"
    }
  )
}

# =============================================================================
# Application Private Subnets (2个) - /20
# =============================================================================

resource "aws_subnet" "app_private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2) # 192.168.32.0/20, 192.168.48.0/20
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-app-private-subnet-${local.subnet_letters[count.index]}"
      Environment = var.environment
      Type        = "Private"
      Tier        = "Application"
    }
  )
}

# =============================================================================
# Database Private Subnets (2个) - /20
# =============================================================================

resource "aws_subnet" "db_private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4) # 192.168.64.0/20, 192.168.80.0/20
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-private-subnet-${local.subnet_letters[count.index]}"
      Environment = var.environment
      Type        = "Private"
      Tier        = "Database"
    }
  )
}

