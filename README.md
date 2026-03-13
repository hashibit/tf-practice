# 整体概览

这个 vpc.tf 在 AWS 上搭了一整套经典的两层网络拓扑：

* 1 个 VPC
* 1 个公有子网 + 1 个私有子网
* Internet Gateway（IGW）让公有子网直连公网
* NAT Gateway + EIP 让私有子网“能上网但不被外面直接访问”
* 两张路由表：公有路由表、私有路由表
* 两组安全组：给公有实例用、给私有实例用


适合做：公有子网放跳板机 / 负载均衡，私有子网放后端服务 / 数据库。


# 图示

```code

                             ┌──────────── Internet ────────────┐
                             │   外部用户 / GitHub / YUM 等     │
                             └───────────▲───────────▲──────────┘
                                         │           │
                                         │           │
                                  入站流量│           │出站流量
                                         │           │
                               ┌─────────┴───────────┴─────────┐
                               │       Internet Gateway (IGW)  │
                               │   aws_internet_gateway.public │
                               └─────────┬───────────┬─────────┘
                                         │           │
                     ====================│===========│================
                     │                   │           │              │
                     │          VPC: chenjie (var.vpc_cidr)        │
                     │          aws_vpc.chenjie                    │
                     │                                             │
                     │   ┌─────────────────────────────────────┐   │
                     │   │          Public Subnet              │   │
                     │   │      aws_subnet.public              │   │
                     │   │      cidr: var.public_subnet_cidr   │   │
                     │   │                                     │   │
                     │   │   ┌──────────────┐      ┌─────────┐ │   │
                     │   │   │ EC2(跳板机)  │      │ NAT GW  │ │   │
                     │   │   │ sg: sg-pub  │      │ nat-01  │ │   │
                     │   │   └─────┬────────┘      │ EIP    │ │   │
                     │   │         │22/tcp         │        │ │   │
                     │   │         │from Internet  │        │ │   │
                     │   └─────────┼───────────────┼────────┘ │   │
                     │             │               │          │   │
                     │  Public RT: │               │          │   │
                     │  aws_route_table.public     │          │   │
                     │   - 0.0.0.0/0 → IGW ────────┘          │   │
                     │                                             │
                     │   ┌─────────────────────────────────────┐   │
                     │   │          Private Subnet             │   │
                     │   │      aws_subnet.private             │   │
                     │   │      cidr: var.private_subnet_cidr  │   │
                     │   │                                     │   │
                     │   │   ┌──────────────┐                  │   │
                     │   │   │ EC2(后端/DB) │                  │   │
                     │   │   │ sg: sg-pvt  │                  │   │
                     │   │   └─────┬────────┘                  │   │
                     │   │         │22/tcp                      │   │
                     │   │         │from Public Subnet CIDR    │   │
                     │   └─────────┼────────────────────────────┘   │
                     │             │                                │
                     │  Private RT: aws_route_table.private         │
                     │   - 0.0.0.0/0 → NAT GW                       │
                     │                                              │
                     ================= VPC 边界 =====================

关键点：
- **IGW**
  - 挂在 VPC 边上，负责 VPC ↔ Internet 的双向通信。
  - 公有子网路由：`0.0.0.0/0 -> IGW`，+ EC2 有公网 IP，→ 可被外网直接访问。

- **NAT GW**
  - 部署在 **Public Subnet**，自身出网也通过 **IGW**。
  - 绑定一个 **EIP**，给私有子网做 **SNAT**。
  - 私有子网路由：`0.0.0.0/0 -> NAT GW`，→ 只能“从内向外访问”，外部不能主动连私网 EC2。

- **Public Subnet**
  - 路由：指向 IGW。
  - 可有跳板机、NAT GW、ALB 等。

- **Private Subnet**
  - 路由：指向 NAT GW。
  - 放后端服务、数据库，只允许从公有子网/特定网段访问。


```



## 2. 流量路径（一步一步看）

2.1 公网 → 公有子网 EC2（跳板机）

* 公网 IP → IGW
* IGW 根据 Public Route Table：0.0.0.0/0 -> IGW 把流量转进 VPC
* 跳板机 EC2 绑定 sg-pub：允许 0.0.0.0/0 的 22 端口 → 可以直接 SSH


2.2 公有子网 EC2（跳板机） → 私有子网 EC2（后端/DB）

* 跳板机在 var.public_subnet_cidr 网段里
* 私有 EC2 绑定 sg-pvt：只允许来自 var.public_subnet_cidr 的 22 端口
* 所以：你先 SSH 到跳板机，再从跳板机 SSH 到私有子网的实例


2.3 私有子网 EC2 出去访问互联网（例如 yum update、拉代码）

* 私有 EC2 出网流量 → 私有路由表 Private RT：0.0.0.0/0 -> NAT GW
* NAT GW 在公有子网，自己通过 IGW 出网，并用 EIP 做源地址转换
* 外面看到的源 IP 是 NAT 的 EIP，而不是私有 EC2 的私网 IP
