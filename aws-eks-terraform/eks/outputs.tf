output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_security_group.node.id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "node_role_arn" {
  description = "IAM role ARN for EKS nodes"
  value       = aws_iam_role.node.arn
}

output "node_groups" {
  description = "EKS node groups"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      id     = v.id
      arn    = v.arn
      status = v.status
    }
  }
}

# Karpenter outputs
output "karpenter_node_role_arn" {
  description = "IAM role ARN for Karpenter nodes"
  value       = var.enable_karpenter ? aws_iam_role.karpenter_node[0].arn : null
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for Karpenter controller"
  value       = var.enable_karpenter ? aws_iam_role.karpenter_controller[0].arn : null
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = var.enable_karpenter ? aws_iam_instance_profile.karpenter[0].name : null
}

output "karpenter_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  value       = var.enable_karpenter ? aws_sqs_queue.karpenter[0].name : null
}

# ALB Controller outputs
output "alb_controller_role_arn" {
  description = "IAM role ARN for ALB controller"
  value       = var.enable_alb_controller ? aws_iam_role.alb_controller[0].arn : null
}

# EBS CSI outputs
output "ebs_csi_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi[0].arn : null
}

# Kubeconfig command
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.main.name}"
}

