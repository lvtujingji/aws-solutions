from aws_cdk import Stack, CfnOutput
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_eks as eks
from constructs import Construct


class NodegroupStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs):
        super().__init__(scope, id, **kwargs)

        # 从 context 读取参数
        cluster_name = self.node.try_get_context("cluster_name")
        vpc_id = self.node.try_get_context("vpc_id")
        nodegroup_name = self.node.try_get_context("nodegroup_name") or "extra-nodes"
        instance_type = self.node.try_get_context("instance_type") or "m7g.large"
        min_size = int(self.node.try_get_context("min_size") or 2)
        max_size = int(self.node.try_get_context("max_size") or 5)
        desired_size = int(self.node.try_get_context("desired_size") or 2)
        disk_size = int(self.node.try_get_context("disk_size") or 50)
        ami_type = self.node.try_get_context("ami_type") or "ARM"
        subnet_type_str = self.node.try_get_context("subnet_type") or "private"  # private 或 public

        # 没传 vpc_id 或 cluster_name 时跳过，避免 synth 其他 stack 时报错
        if not cluster_name or not vpc_id:
            return

        # 查找已有 VPC 和集群
        vpc = ec2.Vpc.from_lookup(self, "ExistingVpc", vpc_id=vpc_id)

        cluster = eks.Cluster.from_cluster_attributes(self, "ExistingCluster",
            cluster_name=cluster_name,
            vpc=vpc,
        )

        # 根据架构选择 AMI 类型
        if ami_type.upper() == "X86":
            node_ami_type = eks.NodegroupAmiType.AL2023_X86_64_STANDARD
        else:
            node_ami_type = eks.NodegroupAmiType.AL2023_ARM_64_STANDARD

        # 选择子网类型
        if subnet_type_str.lower() == "public":
            subnet_selection = ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC)
        else:
            subnet_selection = ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS)

        # 创建节点组
        nodegroup = eks.Nodegroup(self, "Nodegroup",
            cluster=cluster,
            nodegroup_name=nodegroup_name,
            instance_types=[ec2.InstanceType(instance_type)],
            min_size=min_size,
            max_size=max_size,
            desired_size=desired_size,
            disk_size=disk_size,
            ami_type=node_ami_type,
            subnets=subnet_selection,
        )

        CfnOutput(self, "NodegroupName", value=nodegroup.nodegroup_name)
