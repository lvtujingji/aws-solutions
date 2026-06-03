# =============================================================================
# 1. Public Route Table (1个，给2个公有子网共用)
# =============================================================================


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-public-rt"
      Environment = var.environment
      Type        = "Public"
    }
  )
}

# Public route to Internet Gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# 2. Application Private Route Tables (2个，每个应用子网一个)
# =============================================================================

resource "aws_route_table" "app_private" {
  count = 2

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-app-private-rt-${local.subnet_letters[count.index]}"
      Environment = var.environment
      Type        = "Private"
      Tier        = "Application"
    }
  )
}

# Application route to NAT Gateway
resource "aws_route" "app_private_nat" {
  count = var.enable_nat_gateway ? 2 : 0

  route_table_id         = aws_route_table.app_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Associate app private subnets with app route tables
resource "aws_route_table_association" "app_private" {
  count = 2

  subnet_id      = aws_subnet.app_private[count.index].id
  route_table_id = aws_route_table.app_private[count.index].id
}

# =============================================================================
# 3. Database Private Route Tables (2个，每个数据库子网一个)
# =============================================================================

resource "aws_route_table" "db_private" {
  count = 2

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-private-rt-${local.subnet_letters[count.index]}"
      Environment = var.environment
      Type        = "Private"
      Tier        = "Database"
    }
  )
}

# Database route to NAT Gateway (可选，用于软件更新)
resource "aws_route" "db_private_nat" {
  count = var.enable_nat_gateway ? 2 : 0

  route_table_id         = aws_route_table.db_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Associate db private subnets with db route tables
resource "aws_route_table_association" "db_private" {
  count = 2

  subnet_id      = aws_subnet.db_private[count.index].id
  route_table_id = aws_route_table.db_private[count.index].id
}

