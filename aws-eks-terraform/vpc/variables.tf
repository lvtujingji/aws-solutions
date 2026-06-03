variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "myproject"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all private subnets"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# ALB Security Group允许的CIDR
variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Application Security Group允许的端口
variable "app_ports" {
  description = "Application ports to allow"
  type        = list(number)
  default     = [8080, 8443]
}

# RDS配置
variable "rds_port" {
  description = "RDS database port"
  type        = number
  default     = 3306
}

# Redis配置
variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

