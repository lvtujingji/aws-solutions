# =============================================================================
# Karpenter IAM Role for Nodes
# =============================================================================

resource "aws_iam_role" "karpenter_node" {
  count = var.enable_karpenter ? 1 : 0

  name_prefix = "${var.cluster_name}-karpenter-node-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-karpenter-node-role"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy_attachment" "karpenter_node_policies" {
  for_each = var.enable_karpenter ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]) : []

  policy_arn = each.value
  role       = aws_iam_role.karpenter_node[0].name
}

resource "aws_iam_instance_profile" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name_prefix = "${var.cluster_name}-karpenter-"
  role        = aws_iam_role.karpenter_node[0].name

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-karpenter-profile"
      Environment = var.environment
    }
  )
}

# =============================================================================
# Karpenter Controller IAM Role
# =============================================================================

resource "aws_iam_role" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0

  name_prefix = "${var.cluster_name}-karpenter-controller-"

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
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-karpenter-controller-role"
      Environment = var.environment
    }
  )
}

resource "aws_iam_policy" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0

  name_prefix = "${var.cluster_name}-karpenter-controller-"
  description = "IAM policy for Karpenter controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.karpenter_node[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter[0].arn
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-karpenter-controller-policy"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0

  policy_arn = aws_iam_policy.karpenter_controller[0].arn
  role       = aws_iam_role.karpenter_controller[0].name
}

# =============================================================================
# Karpenter SQS Queue for Interruption Handling
# =============================================================================

resource "aws_sqs_queue" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name                      = "${var.cluster_name}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-karpenter-queue"
      Environment = var.environment
    }
  )
}

resource "aws_sqs_queue_policy" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  queue_url = aws_sqs_queue.karpenter[0].url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "events.amazonaws.com",
          "sqs.amazonaws.com"
        ]
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.karpenter[0].arn
    }]
  })
}

# =============================================================================
# EventBridge Rules for Spot Interruption
# =============================================================================

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  count = var.enable_karpenter ? 1 : 0

  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Capture EC2 Spot Instance interruption warnings"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-karpenter-spot-rule"
      Environment = var.environment
    }
  )
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  count = var.enable_karpenter ? 1 : 0

  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption[0].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter[0].arn
}

# =============================================================================
# Karpenter Helm Release
# =============================================================================

resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  namespace  = "karpenter"
  version    = var.karpenter_version

  create_namespace = true

  set {
    name  = "settings.clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = aws_eks_cluster.main.endpoint
  }

  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter[0].name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller[0].arn
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_addon.vpc_cni
  ]
}

# =============================================================================
# Karpenter NodePool (default)
# =============================================================================

resource "kubectl_manifest" "karpenter_node_pool" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            }
          ]
          nodeClassRef = {
            name = "default"
          }
        }
      }
      limits = {
        cpu    = "1000"
        memory = "1000Gi"
      }
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        expireAfter         = "720h"
      }
    }
  })

  depends_on = [helm_release.karpenter]
}

# =============================================================================
# Karpenter EC2NodeClass
# =============================================================================

resource "kubectl_manifest" "karpenter_node_class" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2"
      role      = aws_iam_role.karpenter_node[0].name
      subnetSelectorTerms = [
        {
          tags = {
            "kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
        }
      ]
      userData = base64encode(<<-EOT
        #!/bin/bash
        /etc/eks/bootstrap.sh ${var.cluster_name}
      EOT
      )
      tags = merge(
        var.tags,
        {
          Name                                        = "${var.cluster_name}-karpenter-node"
          Environment                                 = var.environment
          "kubernetes.io/cluster/${var.cluster_name}" = "owned"
        }
      )
    }
  })

  depends_on = [helm_release.karpenter]
}

