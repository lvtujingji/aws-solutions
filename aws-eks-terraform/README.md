# 生产环境 VPC 网络架构说明文档

## 1. 概述

本 VPC 为生产环境提供三层网络隔离架构，部署在 AWS sa-east-1 区域，支持 EKS、RDS、ElastiCache 等服务的高可用部署。

- **项目名称：** myproject
- **环境：** prod
- **区域：** sa-east-1
- **VPC CIDR：** 10.10.0.0/16（65,536 个 IP）
- **可用区：** 3 个（sa-east-1a, sa-east-1b, sa-east-1c）
- **管理方式：** Terraform

---

## 2. 网络架构图

```
                        Internet
                           │
                    ┌──────┴──────┐
                    │     IGW     │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
    │Public-a │      │Public-b │      │Public-c │    ← 公有子网 /24
    │         │      │         │      │         │      ALB, NAT Gateway
    └────┬────┘      └────┬────┘      └────┬────┘
         │                 │                 │
    ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
    │  NAT-a  │      │  NAT-b  │      │  NAT-c  │    ← NAT Gateway (3个高可用)
    └────┬────┘      └────┬────┘      └────┬────┘
         │                 │                 │
    ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
    │Private-a│      │Private-b│      │Private-c│    ← 私有子网 /20
    │         │      │         │      │         │      EKS Nodes, EC2
    └────┬────┘      └────┬────┘      └────┬────┘
         │                 │                 │
    ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
    │Database │      │Database │      │Database │    ← 数据库子网 /24
    │   -a    │      │   -b    │      │   -c    │      RDS, ElastiCache
    └─────────┘      └─────────┘      └─────────┘
```

---

## 3. 子网规划

### 3.1 公有子网（Public）

| 子网 | CIDR | 可用区 | 用途 |
|------|------|--------|------|
| public-a | 10.10.0.0/24 | sa-east-1a | ALB, NAT Gateway |
| public-b | 10.10.1.0/24 | sa-east-1b | ALB, NAT Gateway |
| public-c | 10.10.2.0/24 | sa-east-1c | ALB, NAT Gateway |

- 每个子网 254 个可用 IP
- 自动分配公网 IP（`map_public_ip_on_launch = true`）
- 标签 `kubernetes.io/role/elb = 1`（ALB Controller 自动发现）

### 3.2 私有子网（Private）

| 子网 | CIDR | 可用区 | 用途 |
|------|------|--------|------|
| private-a | 10.10.48.0/20 | sa-east-1a | EKS Nodes, EC2 |
| private-b | 10.10.64.0/20 | sa-east-1b | EKS Nodes, EC2 |
| private-c | 10.10.80.0/20 | sa-east-1c | EKS Nodes, EC2 |

- 每个子网 4,094 个可用 IP
- 通过 NAT Gateway 访问互联网
- 标签 `kubernetes.io/role/internal-elb = 1`（内部 ALB 自动发现）

### 3.3 数据库子网（Database）

| 子网 | CIDR | 可用区 | 用途 |
|------|------|--------|------|
| database-a | 10.10.200.0/24 | sa-east-1a | RDS, ElastiCache |
| database-b | 10.10.201.0/24 | sa-east-1b | RDS, ElastiCache |
| database-c | 10.10.202.0/24 | sa-east-1c | RDS, ElastiCache |

- 每个子网 254 个可用 IP
- 通过 NAT Gateway 访问互联网（用于软件更新）
- 无公网 IP，无法从外部直接访问

---

## 4. 路由设计

### 4.1 公有路由表（1 个，共享）

| 目标 | 下一跳 |
|------|--------|
| 10.10.0.0/16 | local |
| 0.0.0.0/0 | Internet Gateway |

### 4.2 私有路由表（每个子网独立）

| 目标 | 下一跳 |
|------|--------|
| 10.10.0.0/16 | local |
| 0.0.0.0/0 | NAT Gateway（同 AZ） |

### 4.3 数据库路由表

与私有路由表共享（通过 NAT 出网）。

---

## 5. NAT Gateway

| 配置项 | 值 |
|--------|-----|
| 数量 | 3 个（每个 AZ 一个） |
| 高可用 |  单 AZ 故障不影响其他 AZ |
| 费用 | ~$32/月/个 × 3 = ~$96/月 + 数据传输费 |

每个私有/数据库子网通过同 AZ 的 NAT Gateway 出网，避免跨 AZ 流量费。

---

## 6. 安全组设计

### 6.1 流量流向

```
Internet → ALB SG (80/443) → App SG (8080/8443) → RDS SG (3306)
                                                  → Redis SG (6379)
```

### 6.2 安全组规则

| 安全组 | 入站规则 | 出站规则 |
|--------|---------|---------|
| **ALB SG** | 0.0.0.0/0 → 80, 443 | 全部放行 |
| **App SG** | ALB SG → 8080, 8443<br>VPC CIDR → 22 (SSH) | 全部放行 |
| **RDS SG** | App SG → 3306 | 全部放行 |
| **Redis SG** | App SG → 6379 | 全部放行 |

---

## 7. 子网组

| 子网组 | 关联子网 | 用途 |
|--------|---------|------|
| RDS Subnet Group | database-a/b/c | RDS Multi-AZ 部署 |
| ElastiCache Subnet Group | database-a/b/c | Redis 集群部署 |

---

## 8. VPC Endpoints

### S3 Gateway Endpoint

| 配置项 | 值 |
|--------|-----|
| 类型 | Gateway（免费） |
| 服务 | com.amazonaws.{region}.s3 |
| 关联路由表 | Public + Private |
| 费用 | $0（Gateway Endpoint 免费） |

**作用：** VPC 内访问 S3 的流量直接走 AWS 内部网络，不经过 NAT Gateway，节省数据传输费用。

---

## 9. 参数配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `vpc_cidr` | 10.10.0.0/16 | VPC 地址空间 |
| `public_subnet_count` | 3 | 公有子网数量 |
| `app_private_subnet_count` | 3 | 私有子网数量 |
| `db_private_subnet_count` | 3 | 数据库子网数量 |
| `enable_nat_gateway` | true | 启用 NAT |
| `nat_gateway_count` | 3 | NAT 数量（高可用） |
| `app_ports` | [8080, 8443] | 应用端口 |
| `rds_port` | 3306 | 数据库端口 |
| `redis_port` | 6379 | Redis 端口 |

---

## 10. 部署与管理

### 部署

```bash
cd tf/aws-env/vpc
terraform init
terraform plan
terraform apply
```

### 查看输出

```bash
terraform output
```

### 销毁

```bash
terraform destroy
```

---

## 11. 与老环境架构对比

### 老环境架构（仅 Public）

```
Internet ← IGW → Public Subnet（EC2/EKS 直接暴露公网 IP）
```

### 新环境架构（Public + Private + NAT）

```
Internet ← IGW → Public Subnet（ALB、NAT Gateway）
                       ↓ NAT
              Private Subnet（EKS Nodes，无公网 IP）
                       ↓
              Database Subnet（RDS、Redis，完全隔离）
```

### 对比

| | 老环境（Public Only） | 新环境（Private + NAT） |
|--|---------------------|----------------------|
| EKS 节点 | 有公网 IP，直接暴露 | 无公网 IP，隐藏在 NAT 后面 |
| 安全性 |  节点可被公网扫描/攻击 | 节点不可从外部直接访问 |
| 入站流量 | 直接到节点 | 必须经过 ALB |
| 出站流量 | 直接出公网 | 通过 NAT Gateway 出公网 |
| 数据库 | 可能暴露公网 | 完全隔离在数据库子网 |
| 合规性 | 不满足大多数安全合规 | 满足 PCI-DSS、SOC2 等要求 |
| NAT 费用 | $0 | ~$96/月 + 数据传输费 |
| 架构复杂度 | 简单 | 稍复杂（多层子网 + 路由表） |

### NAT Gateway 的好处

1. **安全隔离** — EKS 节点、RDS、Redis 没有公网 IP，无法从外部直接访问
2. **攻击面缩小** — 只有 ALB 暴露在公网，减少被扫描和攻击的风险
3. **出站可控** — 所有出站流量经过 NAT，可以通过安全组和 NACL 控制
4. **合规要求** — 生产环境安全合规通常要求数据库和应用不直接暴露公网
5. **固定出站 IP** — NAT Gateway 的 EIP 是固定的，方便对接第三方白名单

### NAT Gateway 的成本

| 费用项 | 单价 | 3 个 NAT 月费 |
|--------|------|--------------|
| NAT Gateway 小时费 | $0.045/小时 | ~$97/月 |
| 数据处理费 | $0.045/GB | 按实际出站流量 |
| **预估总费用** | | **~$100-200/月**（取决于流量） |

### 降低 NAT 费用的措施

- S3 Gateway Endpoint — S3 流量不走 NAT（已配置）
- 可选：DynamoDB Gateway Endpoint
- 可选：ECR/CloudWatch 等 Interface Endpoint（减少镜像拉取走 NAT）
- 如果流量小，可以用 1 个 NAT 代替 3 个（牺牲高可用换成本）

---

## 12. 设计决策说明

| 决策 | 原因 |
|------|------|
| 3 个 AZ | 生产环境高可用标准 |
| Public/Database 子网 /24 | ALB + NAT + 数据库不需要太多 IP |
| Private 子网 /20 | EKS Pod 需要大量 IP（每个 Pod 一个 ENI IP） |
| 每 AZ 一个 NAT | 避免跨 AZ 流量费 + 单点故障 |
| 安全组引用 SG ID | 比 CIDR 更安全，子网变化不影响规则 |
| Database 子网独立 | 数据库层与应用层网络隔离 |
| K8s 标签 | ALB Controller 自动发现子网，无需手动指定 |
| S3 Gateway Endpoint | 免费，S3 流量不走 NAT 省钱 |
