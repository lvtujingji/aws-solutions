

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-oidc"
      Environment = var.environment
    }
  )
}
# =============================================================================
# AWS Load Balancer Controller IAM Role
# =============================================================================
resource "aws_iam_role" "alb_controller" {
  count = var.enable_alb_controller ? 1 : 0
  name_prefix = "${var.cluster_name}-alb-controller-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-alb-controller-role"
      Environment = var.environment
    }
  )
}
resource "aws_iam_policy" "alb_controller" {
  count = var.enable_alb_controller ? 1 : 0
  name_prefix = "${var.cluster_name}-alb-controller-"
  description = "IAM policy for AWS Load Balancer Controller"
  policy = file("${path.module}/policies/alb-controller-policy.json")
  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-alb-controller-policy"
      Environment = var.environment
    }
  )
}
resource "aws_iam_role_policy_attachment" "alb_controller" {
  count = var.enable_alb_controller ? 1 : 0
  policy_arn = aws_iam_policy.alb_controller[0].arn
  role       = aws_iam_role.alb_controller[0].name
}
# =============================================================================
# EBS CSI Driver IAM Role
# =============================================================================
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  name_prefix = "${var.cluster_name}-ebs-csi-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-ebs-csi-role"
      Environment = var.environment
    }
  )
}
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}

