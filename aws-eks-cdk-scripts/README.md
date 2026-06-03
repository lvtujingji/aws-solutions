该脚本主要由两部分组成：eks集群创建与节点组的创建分别为eks_stack.py与nodegroup_stack.py

操作步骤：
1. 进入项目目录

cd CDK

2. 激活虚拟环境

source .venv/bin/activate

3. 安装依赖

pip install aws-cdk-lib constructs aws-cdk.lambda-layer-kubectl-v31

4. 确保 CDK CLI 是最新的

npm install -g aws-cdk@latest

5. 配置 AWS 凭证（如果还没配置）

aws configure

6. Bootstrap（首次在该账户/区域使用 CDK 需要执行一次）

cdk bootstrap

7. 预览将要创建的资源

cdk synth

8. 部署

cdk deploy

9. 部署完成后，用输出的命令配置 kubeconfig

aws eks update-kubeconfig --name <集群名> --role-arn <MastersRole ARN>

10. 验证集群

kubectl get nodes