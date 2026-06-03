# Elastic IPs for NAT Gateways

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-nat-eip-${local.subnet_letters[count.index]}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways (2个，每个公有子网一个)
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-nat-${local.subnet_letters[count.index]}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.main]
}

