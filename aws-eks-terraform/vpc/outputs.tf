# =============================================================================
# VPC Outputs
# =============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.main.arn
}

# =============================================================================
# Internet Gateway Outputs
# =============================================================================

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# =============================================================================
# Subnet Outputs
# =============================================================================

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidr_blocks" {
  description = "List of CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "app_private_subnet_ids" {
  description = "List of IDs of application private subnets"
  value       = aws_subnet.app_private[*].id
}

output "app_private_subnet_cidr_blocks" {
  description = "List of CIDR blocks of application private subnets"
  value       = aws_subnet.app_private[*].cidr_block
}

output "db_private_subnet_ids" {
  description = "List of IDs of database private subnets"
  value       = aws_subnet.db_private[*].id
}

output "db_private_subnet_cidr_blocks" {
  description = "List of CIDR blocks of database private subnets"
  value       = aws_subnet.db_private[*].cidr_block
}

# =============================================================================
# NAT Gateway Outputs
# =============================================================================

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_eip_public_ips" {
  description = "List of public IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

# =============================================================================
# Route Table Outputs
# =============================================================================

output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

output "app_private_route_table_ids" {
  description = "List of IDs of application private route tables"
  value       = aws_route_table.app_private[*].id
}

output "db_private_route_table_ids" {
  description = "List of IDs of database private route tables"
  value       = aws_route_table.db_private[*].id
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "alb_security_group_id" {
  description = "ID of ALB security group"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID of application security group"
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "ID of RDS security group"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "ID of Redis security group"
  value       = aws_security_group.redis.id
}

# =============================================================================
# Subnet Group Outputs
# =============================================================================

output "rds_subnet_group_name" {
  description = "Name of RDS subnet group"
  value       = aws_db_subnet_group.rds.name
}

output "rds_subnet_group_arn" {
  description = "ARN of RDS subnet group"
  value       = aws_db_subnet_group.rds.arn
}

output "redis_subnet_group_name" {
  description = "Name of ElastiCache subnet group"
  value       = aws_elasticache_subnet_group.redis.name
}

# =============================================================================
# Availability Zones
# =============================================================================

output "availability_zones" {
  description = "List of availability zones used"
  value       = data.aws_availability_zones.available.names
}

