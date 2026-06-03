provider "aws" {
  region = "us-east-2"
}

module "vpc" {

  source = "./vpc"
  project_name = "production-app"
  environment  = "prod"

  vpc_cidr = "192.168.0.0/16"

  # 高可用配置
  enable_nat_gateway = true
  single_nat_gateway = false

  # 应用配置
  app_ports = [8080, 8443]
  rds_port  = 3306
  redis_port = 6379

  # 允许全球访问ALB
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Project    = "ProductionApp"
    Team       = "Platform"
    ManagedBy  = "Terraform"
    CostCenter = "Engineering"
  }
}


module "eks_prod" {
  source = "./eks"
  cluster_name    = "myapp-prod"
  environment     = "prod"
  cluster_version = "1.32"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.app_private_subnet_ids
  control_plane_subnet_ids = module.vpc.app_private_subnet_ids
  # 节点组配置
  node_groups = {
    general = {
      desired_size   = 2
      min_size       = 2
      max_size       = 2
      instance_types = ["t3.xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      labels = {
        role = "general"
      }
      taints = []
    }
  }
  # 启用所有插件
  enable_alb_controller = true
  enable_ebs_csi_driver = true
  enable_karpenter      = true
  karpenter_version     = "v0.33.0"
  # 集群访问
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  # 日志
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  tags = {
    Project     = "MyApp"
    Environment = "Production"
    Team        = "Platform"
    ManagedBy   = "Terraform"
  }
}
# Outputs
output "prod_cluster_endpoint" {
  value = module.eks_prod.cluster_endpoint
}
output "prod_configure_kubectl" {
  value = module.eks_prod.configure_kubectl
}
