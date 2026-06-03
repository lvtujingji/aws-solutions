from aws_cdk import Stack, CfnOutput, Tags
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_eks as eks
from aws_cdk import aws_iam as iam
from aws_cdk.lambda_layer_kubectl_v31 import KubectlV31Layer
from constructs import Construct


class EksStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs):
        super().__init__(scope, id, **kwargs)

        # 从 context 读取参数
        vpc_id = self.node.try_get_context("vpc_id")
        vpc_name = self.node.try_get_context("vpc_name") or "EksVpc"
        cluster_name = self.node.try_get_context("cluster_name") or "my-eks-cluster"

        # ---- VPC ----
        if vpc_id:
            # 使用已有 VPC
            vpc = ec2.Vpc.from_lookup(self, "ExistingVpc", vpc_id=vpc_id)
        else:
            # 创建新 VPC
            vpc = ec2.Vpc(self, "EksVpc",
                vpc_name=vpc_name,
                max_azs=2,
                nat_gateways=1,
            )

        # 为子网打 AWS LB Controller 所需的标签
        for subnet in vpc.public_subnets:
            Tags.of(subnet).add("kubernetes.io/role/elb", "1")
            Tags.of(subnet).add(f"kubernetes.io/cluster/{cluster_name}", "shared")

        for subnet in vpc.private_subnets:
            Tags.of(subnet).add("kubernetes.io/role/internal-elb", "1")
            Tags.of(subnet).add(f"kubernetes.io/cluster/{cluster_name}", "shared")

        # ---- IAM 管理员角色 ----
        masters_role = iam.Role(self, "MastersRole",
            assumed_by=iam.AccountRootPrincipal(),
        )

        # ---- EKS 集群 ----
        cluster = eks.Cluster(self, "EksCluster",
            cluster_name=cluster_name,
            version=eks.KubernetesVersion.V1_31,
            kubectl_layer=KubectlV31Layer(self, "KubectlLayer"),
            vpc=vpc,
            vpc_subnets=[ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS)],
            default_capacity=0,
            masters_role=masters_role,
            endpoint_access=eks.EndpointAccess.PUBLIC_AND_PRIVATE,
        )

        # 给集群打标签
        Tags.of(cluster).add(f"kubernetes.io/cluster/{cluster_name}", "owned")

        # ---- 托管节点组 ----
        cluster.add_nodegroup_capacity("WorkerNodes",
            instance_types=[ec2.InstanceType("m7g.large")],
            min_size=2,
            max_size=5,
            desired_size=2,
            disk_size=50,
            ami_type=eks.NodegroupAmiType.AL2023_ARM_64_STANDARD,
            subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
        )

        # ---- AWS LB Controller 所需的 OIDC + IRSA ----
        sa = cluster.add_service_account("AwsLbControllerSA",
            name="aws-load-balancer-controller",
            namespace="kube-system",
        )

        sa.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("ElasticLoadBalancingFullAccess")
        )

        # ---- 输出 ----
        CfnOutput(self, "ClusterName", value=cluster.cluster_name)
        CfnOutput(self, "KubeconfigCommand",
            value=f"aws eks update-kubeconfig --name {cluster.cluster_name} --role-arn {masters_role.role_arn}",
        )
        CfnOutput(self, "LBControllerRoleArn", value=sa.role.role_arn)
