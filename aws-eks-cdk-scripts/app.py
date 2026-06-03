#!/usr/bin/env python3
import aws_cdk as cdk
from eks_stack import EksStack
from nodegroup_stack import NodegroupStack

app = cdk.App()

env = cdk.Environment(
    account="xxxxxx",
    region="ap-east-1"
)

EksStack(app, "EksClusterStack", env=env)
NodegroupStack(app, "NodegroupStack", env=env)

app.synth()
