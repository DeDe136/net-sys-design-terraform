# AWS Infrastructure — Terraform

Hạ tầng AWS multi-VPC triển khai bằng Terraform, theo kiến trúc enterprise với Production VPC và R&D VPC tách biệt hoàn toàn, kết nối qua Transit Gateway.

---

## Mục lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Cấu trúc thư mục](#2-cấu-trúc-thư-mục)
3. [Luồng traffic](#3-luồng-traffic)
4. [Điều kiện tiên quyết](#4-điều-kiện-tiên-quyết)
5. [Cấu hình xác thực AWS](#5-cấu-hình-xác-thực-aws)
6. [Triển khai lần đầu](#6-triển-khai-lần-đầu)
7. [Quản lý secrets](#7-quản-lý-secrets)
8. [Môi trường & Workspace](#8-môi-trường--workspace)
9. [Thứ tự dependency](#9-thứ-tự-dependency)
10. [Outputs quan trọng](#10-outputs-quan-trọng)
11. [Chi phí ước tính](#11-chi-phí-ước-tính)
12. [Xóa hạ tầng](#12-xóa-hạ-tầng)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Tổng quan kiến trúc

```
Internet
    │
    ▼
ALB (Internet-facing, public subnets AZ-1a + AZ-1b)
    │  chỉ load balance EC2 Web Portal
    ▼
┌─────────────────────────────────────────────────────┐
│ Production VPC  10.0.0.0/16                         │
│                                                     │
│  AZ-1a                        AZ-1b                 │
│  ┌──────────────────┐  ┌──────────────────┐         │
│  │ Public Subnet    │  │ Public Subnet    │         │
│  │ NAT GW + ALB     │  │ NAT GW + ALB     │         │
│  └────────┬─────────┘  └────────┬─────────┘         │
│           │ (NAT outbound)      │                   │
│  ┌────────▼─────────┐  ┌────────▼─────────┐         │
│  │ Private Subnet   │  │ Private Subnet   │         │
│  │ EC2 Web Portal ◄─┼ALB│ EC2 Web Portal  │         │
│  │ EC2 ERP/CRM ◄────┼Web│ EC2 ERP/CRM     │         │
│  └──────────────────┘  └──────────────────┘         │
│  ┌──────────────────┐  ┌──────────────────┐         │
│  │ DB Subnet        │  │ DB Subnet        │         │
│  │ Directory Svc    │  │ Directory Svc    │         │
│  │ RDS Primary      │  │ RDS Standby      │         │
│  └──────────────────┘  └──────────────────┘         │
│                           ▲ TGW Attachment           │
└───────────────────────────┼─────────────────────────┘
                            │
                   Transit Gateway
                            │
┌───────────────────────────┼─────────────────────────┐
│ R&D VPC  10.1.0.0/16      │                         │
│                           ▼ TGW Attachment           │
│  AZ-2a                        AZ-2b                 │
│  ┌──────────────────┐  ┌──────────────────┐         │
│  │ Public Subnet    │  │ Public Subnet    │         │
│  │ NAT GW           │  │ NAT GW           │         │
│  └────────┬─────────┘  └────────┬─────────┘         │
│           │ (NAT outbound)      │                   │
│  ┌────────▼─────────┐  ┌────────▼─────────┐         │
│  │ Private Subnet   │  │ Private Subnet   │         │
│  │ 4x EC2 R&D       │  │ 4x EC2 R&D       │         │
│  │ (mount EFS)      │  │ (mount EFS)      │         │
│  └──────────────────┘  └──────────────────┘         │
│                                                     │
│              EFS Project Data                       │
│              S3 Gateway Endpoint                    │
└─────────────────────────────────────────────────────┘
                            │
                   Transit Gateway
                            │
                    Client VPN ◄── Remote Staff
```

### Thành phần chính

| Thành phần | VPC | Mô tả |
|---|---|---|
| ALB | Production | Internet-facing, chỉ forward đến EC2 Web Portal |
| EC2 Web Portal | Production | ASG multi-AZ, nhận traffic từ ALB |
| EC2 ERP/CRM | Production | ASG multi-AZ, nhận traffic **nội bộ** từ Web Portal |
| RDS MySQL 8.0 | Production | Multi-AZ (Primary AZ-1a + Standby AZ-1b) |
| Directory Service | Production | AWS Managed Microsoft AD, xác thực người dùng |
| EC2 R&D | R&D | 4 instance/AZ, không gắn ALB, cập nhật qua NAT |
| EFS | R&D | Shared storage mount vào tất cả EC2 R&D |
| S3 | Shared | Truy cập từ cả 2 VPC qua Gateway Endpoint |
| Transit Gateway | Shared | Kết nối Production ↔ R&D ↔ Client VPN |
| Client VPN | Production | Remote Staff kết nối qua OpenVPN |

---

## 2. Cấu trúc thư mục

```
terraform-project/
│
├── main.tf                         # Root module — orchestrate toàn bộ modules
├── variables.tf                    # Khai báo tất cả input variables
├── outputs.tf                      # Outputs sau khi apply (VPC IDs, ALB DNS,...)
├── terraform.tfvars                # Giá trị mặc định (commit được, không có secrets)
├── secret.tfvars                   # Credentials + passwords — KHÔNG commit (gitignored)
├── secret.tfvars.example           # File mẫu để tạo secret.tfvars (commit được)
├── providers.tf                    # AWS provider + 4 phương thức xác thực
├── versions.tf                     # Terraform & provider version constraints
├── backend.tf                      # Remote state config (S3 + DynamoDB locking)
├── .gitignore                      # Bảo vệ state, certs, secrets khỏi git
│
├── modules/                        # Reusable Terraform modules
│   │
│   ├── vpc/                        # VPC + Internet Gateway
│   │   ├── main.tf                 #   Tạo aws_vpc + aws_internet_gateway
│   │   ├── variables.tf            #   vpc_cidr, vpc_name
│   │   └── outputs.tf              #   vpc_id, igw_id
│   │
│   ├── subnets/                    # Subnets + NAT Gateways + Route Tables
│   │   ├── main.tf                 #   Public/Private/DB subnets, NAT GW mỗi AZ,
│   │   │                           #   route tables với default route → NAT,
│   │   │                           #   cross-VPC route → Transit Gateway
│   │   ├── variables.tf            #   CIDR blocks, AZ names, igw_id, tgw_id
│   │   └── outputs.tf              #   subnet IDs, route table IDs
│   │
│   ├── security_groups/            # Tất cả Security Groups theo env
│   │   ├── main.tf                 #   prod: sg-alb, sg-ec2-web, sg-ec2-erp,
│   │   │                           #         sg-rds, sg-ds
│   │   │                           #   rnd:  sg-rnd-ec2, sg-efs
│   │   ├── variables.tf            #   vpc_id, env, vpn_cidr, rnd_vpc_cidr
│   │   └── outputs.tf              #   sg IDs cho từng resource
│   │
│   ├── alb/                        # Application Load Balancer (Production only)
│   │   ├── main.tf                 #   aws_lb + Target Group Web Portal + Listener
│   │   │                           #   ⚠ Chỉ 1 target group (web) — không có ERP
│   │   ├── variables.tf            #   name, vpc_id, public_subnet_ids, sg_alb_id
│   │   └── outputs.tf              #   alb_arn, alb_dns_name, web_tg_arn
│   │
│   ├── ec2/                        # EC2 instances (Production ASG + R&D fixed)
│   │   ├── main.tf                 #   prod: Launch Template + ASG cho web-portal
│   │   │                           #         Launch Template + ASG cho erp-crm
│   │   │                           #         (erp-crm KHÔNG gắn ALB target group)
│   │   │                           #   rnd:  aws_instance × N/AZ, user_data
│   │   │                           #         cập nhật gói qua NAT Gateway
│   │   ├── variables.tf            #   env, ami, instance_type, subnet IDs,
│   │   │                           #   sg IDs, alb_web_tg_arn, ASG min/max/desired
│   │   └── outputs.tf              #   ASG names, instance IDs
│   │
│   ├── rds/                        # RDS MySQL Multi-AZ
│   │   ├── main.tf                 #   aws_db_subnet_group + aws_db_instance
│   │   │                           #   multi_az = true, skip_final_snapshot = true*
│   │   ├── variables.tf            #   db_subnet_ids, sg_rds_id, engine, credentials
│   │   └── outputs.tf              #   rds_endpoint, rds_arn
│   │
│   ├── directory_service/          # AWS Managed Microsoft AD
│   │   ├── main.tf                 #   aws_directory_service_directory (MicrosoftAD)
│   │   ├── variables.tf            #   vpc_id, subnet_ids, directory_name, password
│   │   └── outputs.tf              #   directory_id, dns_ip_addrs
│   │
│   ├── efs/                        # EFS File System (R&D)
│   │   ├── main.tf                 #   aws_efs_file_system + mount targets mỗi AZ
│   │   ├── variables.tf            #   subnet_ids, sg_efs_id, name
│   │   └── outputs.tf              #   efs_id, efs_dns_name
│   │
│   ├── s3/                         # S3 Bucket + Bucket Policy
│   │   ├── main.tf                 #   aws_s3_bucket, versioning, encryption,
│   │   │                           #   bucket policy giới hạn chỉ từ VPC Endpoints
│   │   ├── variables.tf            #   bucket_name, vpc_endpoint_ids
│   │   └── outputs.tf              #   bucket_name, bucket_arn
│   │
│   ├── endpoints/                  # VPC Gateway Endpoints (S3)
│   │   ├── main.tf                 #   aws_vpc_endpoint type=Gateway cho S3
│   │   │                           #   gắn vào tất cả route tables của VPC
│   │   ├── variables.tf            #   vpc_id, route_table_ids, aws_region, name
│   │   └── outputs.tf              #   endpoint_id
│   │
│   ├── transit_gateway/            # Transit Gateway + VPC Attachments
│   │   ├── main.tf                 #   aws_ec2_transit_gateway
│   │   │                           #   aws_ec2_transit_gateway_vpc_attachment × 2
│   │   │                           #   aws_ec2_transit_gateway_route_table_association
│   │   ├── variables.tf            #   prod_vpc_id, rnd_vpc_id, subnet_ids
│   │   └── outputs.tf              #   tgw_id, attachment IDs
│   │
│   └── vpn/                        # Client VPN Endpoint
│       ├── main.tf                 #   aws_ec2_client_vpn_endpoint
│       │                           #   aws_ec2_client_vpn_network_association
│       │                           #   aws_ec2_client_vpn_authorization_rule
│       ├── variables.tf            #   client_cidr, server/client cert ARNs
│       └── outputs.tf              #   vpn_endpoint_id, vpn_endpoint_dns
│
├── environments/                   # Giá trị biến theo môi trường
│   ├── production/
│   │   └── terraform.tfvars        # Prod: instance type lớn hơn, ASG cao hơn
│   └── rnd/
│       └── terraform.tfvars        # R&D: t3.micro, 4 instances/AZ
│
├── global/                         # Tài nguyên IAM dùng chung (deploy 1 lần)
│   └── iam.tf                      # ec2-instance-role (SSM + S3),
│                                   # ec2-instance-profile,
│                                   # client-vpn-cloudwatch-role
│
├── scripts/
│   ├── bootstrap_backend.sh        # Tạo S3 bucket + DynamoDB cho remote state
│   ├── generate_vpn_certs.sh       # Tạo PKI bằng easy-rsa, import vào ACM
│   ├── generate_ovpn.sh            # Xuất file .ovpn cho remote staff
│   └── plan.sh                     # terraform fmt + validate + plan -out=tfplan
│
└── templates/
    └── client.ovpn.tpl             # Template cấu hình OpenVPN client
```

> `*` `skip_final_snapshot = true` phù hợp cho dev/test. **Đổi thành `false` cho Production thực tế.**

---

## 3. Luồng traffic

### Production — Inbound (Internet → EC2)
```
Remote User
    │ HTTPS/HTTP
    ▼
ALB (Internet-facing)
    │ forward đến target group web-portal
    ▼
EC2 Web Portal (private subnet, port 80/443)
    │ internal request, port 8080/8443
    ▼
EC2 ERP/CRM (private subnet)
    │ port 3306
    ▼
RDS MySQL Primary
```

> EC2 ERP/CRM **không** nhận traffic trực tiếp từ ALB. ALB chỉ có 1 target group trỏ vào Web Portal.

### Production / R&D — Outbound (EC2 → Internet)
```
EC2 Web Portal / EC2 ERP/CRM / EC2 R&D
    │ (nằm trong private subnet)
    │ route: 0.0.0.0/0 → NAT Gateway
    ▼
NAT Gateway (public subnet)
    │
    ▼
Internet Gateway → Internet
```
Mọi EC2 (kể cả R&D) cập nhật packages `yum update`, download dependencies qua NAT Gateway — không cần public IP.

### Remote Staff → Hạ tầng
```
Remote Staff
    │ OpenVPN (172.16.0.0/22)
    ▼
Client VPN Endpoint (Production VPC)
    │
    ▼
Transit Gateway
    ├──► Production VPC (10.0.0.0/16)
    └──► R&D VPC (10.1.0.0/16)
```

### S3 Access (không qua Internet)
```
EC2 (Production hoặc R&D)
    │
    ▼
VPC Gateway Endpoint (com.amazonaws.*.s3)
    │ traffic không rời VPC
    ▼
Amazon S3
```

---

## 4. Điều kiện tiên quyết

| Công cụ | Version | Ghi chú |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.3.0 | Bắt buộc |
| AWS credentials | — | Xem mục 5 (không cần AWS CLI) |
| [easy-rsa](https://github.com/OpenVPN/easy-rsa) | >= 3.x | Chỉ cần nếu dùng Client VPN |

**Không bắt buộc phải cài AWS CLI.** Terraform đọc credentials trực tiếp từ file hoặc biến môi trường.

---

## 5. Cấu hình xác thực AWS

Tất cả thông tin xác thực được đặt trong `secret.tfvars` (đã có trong `.gitignore`, không commit). Tạo file từ template:

```bash
cp secret.tfvars.example secret.tfvars
```

Mở `secret.tfvars` và chọn **1 trong 4 phương thức**, bỏ trống (`""`) các phương thức còn lại:

### Phương thức 1 — Named Profile (khuyến nghị cho local dev)

Tạo file `~/.aws/credentials` (không cần AWS CLI, chỉ cần file text):

```ini
[my-project]
aws_access_key_id     = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

Trong `secret.tfvars`:

```hcl
aws_profile = "my-project"
```

### Phương thức 2 — Access Key trực tiếp

Trong `secret.tfvars`:

```hcl
aws_profile    = ""
aws_access_key = "AKIAIOSFODNN7EXAMPLE"
aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

### Phương thức 3 — Assume IAM Role (khuyến nghị cho multi-account / CI với IAM)

Kết hợp với phương thức 1 hoặc 2, thêm vào `secret.tfvars`:

```hcl
aws_role_arn         = "arn:aws:iam::123456789012:role/TerraformDeployRole"
aws_role_external_id = ""   # để trống nếu role không yêu cầu
```

### Phương thức 4 — Environment Variables (khuyến nghị cho CI/CD)

Để `aws_profile = ""` trong `secret.tfvars`, sau đó export:

```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="us-east-1"
```

Terraform tự động đọc các biến trên, không cần khai báo thêm.

---

## 6. Triển khai lần đầu

> **Tổng quan thứ tự:** Clone → IAM global → (tùy chọn) Remote state → (tùy chọn) VPN certs → Điền `secret.tfvars` → Cập nhật `terraform.tfvars` → Apply giai đoạn 1 → Apply giai đoạn 2 → (tùy chọn) Tạo file `.ovpn`

---

### Bước 1 — Clone repo & kiểm tra cấu trúc

```bash
git clone <repo-url>
cd net-sys-design-terraform
ls
```

Xác nhận có đủ các file sau trước khi tiếp tục:

```
main.tf  variables.tf  terraform.tfvars  secret.tfvars.example
backend.tf  providers.tf  versions.tf  outputs.tf
modules/  global/  environments/  scripts/
```

---

### Bước 2 — Deploy IAM global (chạy 1 lần duy nhất)

IAM roles và instance profiles được tách riêng vào `global/iam.tf` để tránh bị tạo lại mỗi lần apply ở root module. Đây là bước **bắt buộc** trước khi deploy hạ tầng chính vì EC2 cần `ec2-instance-profile` để SSM Session Manager và S3 access hoạt động.

```bash
cd global
terraform init
terraform apply
```

Khi Terraform hỏi `Do you want to perform these actions?`, nhập `yes`.

Sau khi apply xong, quay về thư mục gốc:

```bash
cd ..
```

> **Kiểm tra:** Vào AWS Console → IAM → Roles → tìm `ec2-ssm-s3-role` và `client-vpn-cloudwatch-role`. Vào Instance Profiles → tìm `ec2-instance-profile`.

---

### Bước 3 — Bootstrap remote state (khuyến nghị cho team / CI)

Remote state lưu `terraform.tfstate` trên S3 thay vì máy cục bộ, đồng thời dùng DynamoDB để lock khi nhiều người hoặc CI chạy đồng thời. Bỏ qua bước này nếu chỉ làm một mình và chỉ dùng local state (dev/test).

**Script yêu cầu AWS CLI đã được cấu hình (chỉ cho bước bootstrap này):**

```bash
# Cấp quyền thực thi nếu chưa có
chmod +x scripts/bootstrap_backend.sh

# Chạy script — tự động lấy Account ID từ AWS STS
bash scripts/bootstrap_backend.sh
```

Script tạo hai tài nguyên:
- **S3 bucket** `tfstate-aws-infra-<account_id>` — versioning bật, public access block, SSE-S3 encryption.
- **DynamoDB table** `terraform-state-lock` — PAY_PER_REQUEST, dùng để lock state khi apply.

Sau khi script chạy xong, nó sẽ in ra Account ID. Ghi lại giá trị này, sau đó mở `backend.tf` và **uncomment** block backend, thay `<account_id>` bằng số thực tế:

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-aws-infra-123456789012"   # ← thay Account ID của bạn
    key            = "aws-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

Re-init để Terraform migrate state local lên S3:

```bash
terraform init -reconfigure
```

Terraform sẽ hỏi `Do you want to copy existing state to the new backend?` → nhập `yes`.

> **Bỏ qua bước này (local state):** Giữ nguyên `backend.tf` (để comment), chạy `terraform init` bình thường. State sẽ lưu tại `terraform.tfstate` trong thư mục gốc — **không commit file này lên git**.

---

### Bước 4 — Tạo VPN certificates và import vào ACM (bỏ qua nếu chưa cần VPN)

Client VPN yêu cầu server certificate và CA certificate đã có trong AWS ACM **trước khi** chạy `terraform apply`. Module `client_vpn` trong `main.tf` hiện đang được comment out — bỏ qua bước này hoàn toàn nếu chưa cần VPN.

**Yêu cầu:** `git` và `easy-rsa` (script sẽ tự clone nếu chưa có).

```bash
chmod +x scripts/generate_vpn_certs.sh
bash scripts/generate_vpn_certs.sh
```

Script thực hiện:
1. Clone easy-rsa vào `/tmp/easy-rsa` (nếu chưa có).
2. Khởi tạo PKI, build CA, tạo server cert và client cert.
3. Import server cert + CA chain vào ACM, in ra 2 ARN.

Output mẫu:

```
=== Import hoàn tất ===
  export TF_VAR_vpn_server_certificate_arn="arn:aws:acm:us-east-1:123456789012:certificate/aaa-bbb"
  export TF_VAR_vpn_client_certificate_arn="arn:aws:acm:us-east-1:123456789012:certificate/ccc-ddd"
```

Điền 2 ARN này vào `secret.tfvars` (xem Bước 5), **không dùng** `export TF_VAR_*` vì project đã quản lý qua `secret.tfvars`.

Sau đó mở `main.tf` và **bỏ comment** block `module "client_vpn"`, đồng thời bỏ comment output `client_vpn_dns` trong `outputs.tf`.

> **Không cần VPN:** Giữ `module "client_vpn"` commented out trong `main.tf`. Bỏ qua bước này hoàn toàn.

---

### Bước 5 — Chuẩn bị file `secret.tfvars`

Tạo `secret.tfvars` từ file mẫu:

```bash
cp secret.tfvars.example secret.tfvars
```

Mở `secret.tfvars` và điền đầy đủ các giá trị bên dưới. File này **không được commit** (đã có trong `.gitignore`).

```hcl
# ── Xác thực AWS — chọn 1 phương thức, bỏ trống phần còn lại ────
aws_profile = "my-project"   # Phương thức 1: Named Profile (khuyến nghị local dev)
                              # Hoặc để "" nếu dùng env vars / EC2 Instance Role

# aws_access_key = "AKIAIOSFODNN7EXAMPLE"   # Phương thức 2: Access Key trực tiếp
# aws_secret_key = "wJalrXUtnFEMI/..."

# aws_role_arn = "arn:aws:iam::123456789012:role/TerraformDeployRole"  # Phương thức 3

# ── Passwords bắt buộc ───────────────────────────────────────────
rds_password          = "YourSecureRDSPassword123!"
ds_directory_password = "YourADPassword123@"

# ── VPN cert ARNs (chỉ cần nếu dùng Client VPN) ──────────────────
vpn_server_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/aaa-bbb"
vpn_client_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/ccc-ddd"
```

**Yêu cầu password cho AWS Managed AD** (`ds_directory_password`):
- Tối thiểu 8 ký tự
- Phải có: chữ hoa, chữ thường, số, ký tự đặc biệt (`!@#$%^&*`)
- Không được chứa tên domain — ví dụ nếu `ds_directory_name = "corp.example.com"` thì password không được chứa `corp` hay `example`

---

### Bước 6 — Cập nhật `terraform.tfvars`

Mở `terraform.tfvars` và thay thế các placeholder còn lại:

```hcl
# Bắt buộc: thay <account_id> bằng AWS Account ID thực (12 chữ số)
# S3 bucket name phải globally unique trên toàn AWS
s3_bucket_name = "s3-prod-shared-123456789012"

# Xác nhận enable_tgw_routes = false (mặc định cho Apply giai đoạn 1)
enable_tgw_routes = false
```

Lấy AWS Account ID nếu chưa biết:

```bash
# Dùng AWS CLI nếu đã cài
aws sts get-caller-identity --query Account --output text

# Hoặc vào AWS Console → góc trên phải → tên account → Account ID
```

---

### Bước 7 — Init, Plan và Apply theo 2 giai đoạn

Do Transit Gateway attachment cần subnet ID (được tạo ở bước subnet), trong khi route table của subnet lại cần Transit Gateway attachment ID đã tồn tại — đây là circular dependency. Giải pháp dùng flag `enable_tgw_routes`: lần apply đầu tạo toàn bộ hạ tầng kể cả TGW attachment nhưng **chưa tạo route**, lần apply thứ hai mới bật route.

#### Giai đoạn 1 — Tạo toàn bộ hạ tầng (chưa có TGW routes)

```bash
# Init — tải providers và modules (bắt buộc lần đầu)
terraform init

# Format + validate + tạo plan (enable_tgw_routes=false, mặc định)
bash scripts/plan.sh

# Xem plan output, kiểm tra số resource sẽ được tạo (~60–70 resources)
# Sau đó apply
terraform apply tfplan
```

Khi Terraform hỏi xác nhận, nhập `yes`. Thời gian chờ giai đoạn 1: **~45–60 phút** (chủ yếu do RDS Multi-AZ ~15–20 phút và Directory Service ~20–40 phút).

Sau khi apply xong, kiểm tra Transit Gateway attachment đã ở trạng thái `available`:

```bash
terraform output tgw_id
# Dùng ID trên để kiểm tra trong AWS Console: VPC → Transit Gateways → Attachments
# Hoặc dùng AWS CLI:
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=<tgw_id>" \
  --query "TransitGatewayAttachments[*].{State:State,VpcId:ResourceId}"
```

Chỉ tiếp tục Giai đoạn 2 khi **cả 2 attachment** đều ở trạng thái `available`.

#### Giai đoạn 2 — Bật TGW routes liên VPC

```bash
# Plan giai đoạn 2 — truyền enable_tgw_routes=true qua tham số script
bash scripts/plan.sh true

# Kiểm tra plan: chỉ nên thấy các aws_route resource được tạo thêm (4 routes)
# Không có resource nào bị destroy
terraform apply tfplan
```

Plan giai đoạn 2 tạo 4 routes:
- `rt-prod-private-1a` → `10.1.0.0/16` via Transit Gateway
- `rt-prod-private-1b` → `10.1.0.0/16` via Transit Gateway
- `rt-rnd-private-2a` → `10.0.0.0/16` via Transit Gateway
- `rt-rnd-private-2b` → `10.0.0.0/16` via Transit Gateway

> **Lưu ý:** Bạn cũng có thể sửa trực tiếp `enable_tgw_routes = true` trong `terraform.tfvars` thay vì dùng tham số script — cả hai cách cho kết quả giống nhau.

Sau khi giai đoạn 2 apply xong, cập nhật lại `terraform.tfvars` để lưu trạng thái:

```hcl
enable_tgw_routes = true
```

#### Apply trực tiếp (không dùng script `plan.sh`)

Nếu không muốn dùng script, có thể chạy thủ công:

```bash
# Giai đoạn 1
terraform plan  -var-file="secret.tfvars" -var="enable_tgw_routes=false" -out=tfplan
terraform apply tfplan

# Giai đoạn 2
terraform plan  -var-file="secret.tfvars" -var="enable_tgw_routes=true" -out=tfplan
terraform apply tfplan
```

---

### Bước 8 — Xác nhận hạ tầng hoạt động

Sau khi apply thành công, lấy các output quan trọng:

```bash
terraform output
```

Kiểm tra nhanh các thành phần chính:

```bash
# ALB DNS — truy cập thử từ browser hoặc curl
terraform output prod_alb_dns
curl -I http://$(terraform output -raw prod_alb_dns)

# RDS endpoint — kiểm tra kết nối từ EC2 Web Portal (qua SSM Session Manager)
terraform output rds_endpoint

# EFS DNS — kiểm tra mount trên EC2 R&D
terraform output efs_dns_name

# Transit Gateway ID — kiểm tra routing giữa 2 VPC
terraform output tgw_id
```

---

### Bước 9 — Tạo file `.ovpn` cho remote staff (chỉ khi đã bật Client VPN)

```bash
chmod +x scripts/generate_ovpn.sh
bash scripts/generate_ovpn.sh
# Output: client-vpn.ovpn
```

File `.ovpn` chứa private key của client — **không commit lên git, không gửi qua email thường**. Phân phát qua kênh bảo mật (1Password, Signal, portal nội bộ, v.v.).

Mỗi nhân viên remote staff cài [AWS VPN Client](https://aws.amazon.com/vpn/client-vpn-download/) và import file `.ovpn` để kết nối.

---

## 7. Quản lý secrets

| Secret | Cách set | Lưu trữ |
|---|---|---|
| RDS password | `secret.tfvars` → `rds_password` | AWS Secrets Manager (khuyến nghị prod) |
| AD password | `secret.tfvars` → `ds_directory_password` | AWS Secrets Manager |
| VPN cert ARNs | `secret.tfvars` → `vpn_*_certificate_arn` | AWS ACM (đã import) |
| AWS credentials | `secret.tfvars` → `aws_profile` / `aws_access_key` | `~/.aws/credentials` hoặc CI secrets |

**Không bao giờ:**
- Commit file `*.tfstate` vào git (chứa toàn bộ resource attributes dạng plaintext)
- Commit `secret.tfvars` vào git (đã có trong `.gitignore`)
- Commit `*.pem`, `*.key`, `*.ovpn`

---

## 8. Môi trường & Workspace

Project hỗ trợ deploy độc lập cho từng môi trường qua Terraform workspace:

```bash
# Tạo workspace production
terraform workspace new production
terraform apply -var-file="secret.tfvars" -var-file=environments/production/terraform.tfvars

# Tạo workspace r&d
terraform workspace new rnd
terraform apply -var-file="secret.tfvars" -var-file=environments/rnd/terraform.tfvars

# Xem danh sách workspace
terraform workspace list

# Switch workspace
terraform workspace select production
```

### Sự khác biệt giữa môi trường

| Tham số | `terraform.tfvars` (default) | `environments/production/` | `environments/rnd/` |
|---|---|---|---|
| `ec2_instance_type` | `t3.micro` | `t3.small` | `t3.micro` |
| `asg_web_min` | 1 | 2 | — |
| `asg_web_max` | 4 | 6 | — |
| `rnd_instance_count_per_az` | 4 | — | 4 |

---

## 9. Thứ tự dependency

Terraform tự xử lý dependency graph dựa trên references giữa các module. Thứ tự logic trong `main.tf`:

```
Phase 1A: prod_vpc + rnd_vpc
          (tạo VPC + IGW độc lập nhau)
    │
    ▼
Phase 1B: transit_gateway
          (tạo TGW, chưa attach — subnet IDs chưa có)
    │
    ▼
Phase 2:  prod_subnets + rnd_subnets
          (public/private/db subnets, NAT GW mỗi AZ,
           route tables với route → NAT và → TGW)
    │
    ▼
Phase 3:  tgw_attachments
          (attach TGW vào private subnets của cả 2 VPC)
    │
    ▼
Phase 4:  prod_security_groups + rnd_security_groups
          │
          ├──► prod_alb
          │        └──► prod_ec2 (web ASG gắn ALB target group)
          │                      (erp ASG không gắn ALB)
          │
          ├──► prod_rds
          ├──► prod_directory_service
          │
          ├──► rnd_ec2 (fixed instances, cập nhật qua NAT)
          ├──► rnd_efs
          │
          ├──► prod_s3_endpoint + rnd_s3_endpoint
          │        └──► s3 (bucket policy sau khi có endpoint IDs)
          │
          └──► client_vpn
```

> **Lưu ý:** Transit Gateway được tạo 2 lần trong `main.tf` (`module "transit_gateway"` và `module "tgw_attachments"`) vì attachment cần subnet IDs chỉ có sau Phase 2. Đây là pattern phổ biến để tránh circular dependency.

---

## 10. Outputs quan trọng

Sau khi `terraform apply` thành công, lấy outputs:

```bash
terraform output
```

| Output | Mô tả | Dùng để |
|---|---|---|
| `prod_alb_dns` | DNS name của ALB | Trỏ domain, test kết nối |
| `rds_endpoint` | RDS Primary endpoint | Cấu hình connection string app |
| `directory_dns_ips` | DNS IPs của Managed AD | Join domain, cấu hình LDAP |
| `efs_dns_name` | EFS DNS | Mount vào EC2 R&D |
| `tgw_id` | Transit Gateway ID | Debug routing |
| `client_vpn_dns` | VPN endpoint DNS | Tạo file .ovpn |
| `s3_bucket_name` | Tên S3 bucket | Upload/download artifacts |

Lấy output cụ thể:

```bash
terraform output prod_alb_dns
terraform output -raw rds_endpoint
```

---

## 11. Chi phí ước tính

Chi phí tháng tại `us-east-1` với cấu hình mặc định (`terraform.tfvars`):

| Resource | Số lượng | Chi phí/tháng |
|---|---|---|
| EC2 t3.micro — Web Portal ASG (desired 2) | 2 | ~$15 |
| EC2 t3.micro — ERP/CRM ASG (desired 2) | 2 | ~$15 |
| EC2 t3.micro — R&D Testing | 8 | ~$60 |
| NAT Gateway (4 AZ) | 4 | ~$130 |
| RDS db.t3.medium Multi-AZ | 1 | ~$100 |
| ALB | 1 | ~$20 |
| Directory Service Standard | 1 | ~$150 |
| Client VPN Endpoint | 1 | ~$72 |
| EFS (phụ thuộc storage) | — | ~$0.30/GB |
| Transit Gateway | 1 | ~$36 + data |
| S3, CloudWatch Logs | — | < $5 |
| **Tổng ước tính** | | **~$600–650/tháng** |

> ⚠️ Con số trên chỉ mang tính tham khảo. Chi phí thực tế phụ thuộc vào data transfer, storage usage và thời gian instance chạy. Dùng [AWS Pricing Calculator](https://calculator.aws) để tính chính xác.

**Tiết kiệm chi phí cho dev/test:**
- Comment out `module "prod_directory_service"` (tiết kiệm ~$150/tháng)
- Comment out `module "client_vpn"` (tiết kiệm ~$72/tháng)
- Giảm `rnd_instance_count_per_az = 1` hoặc 2

---

## 12. Xóa hạ tầng

```bash
terraform destroy -var-file="secret.tfvars"
```

**Trước khi destroy, lưu ý:**

- RDS có `skip_final_snapshot = true` — **dữ liệu sẽ mất vĩnh viễn**. Thay thành `false` và đặt `final_snapshot_identifier` cho Production thực tế.
- S3 bucket có thể không xóa được nếu còn objects. Xóa objects trước hoặc bật `force_destroy = true` trong `modules/s3/main.tf`.
- Directory Service mất khoảng 10–15 phút để xóa hoàn toàn.

---

## 13. Troubleshooting

### `Error: S3 bucket already exists`
Bucket name phải globally unique trên toàn AWS. Đổi `s3_bucket_name` trong `terraform.tfvars`:
```hcl
s3_bucket_name = "s3-prod-shared-<account_id>-<suffix>"
```

### `Error: InvalidParameterException — The specified directory password is invalid`
Password cho AWS Managed AD không đủ complexity. Yêu cầu: 8+ ký tự, chữ hoa + thường + số + ký tự đặc biệt, không chứa tên directory.

### `Error: Certificate not found`
VPN certificates chưa được import vào ACM. Chạy:
```bash
bash scripts/generate_vpn_certs.sh
```
R��i export đúng ARN vào `TF_VAR_vpn_*_certificate_arn`.

### `Error: InvalidClientToken — transit gateway attachment`
Transit Gateway attachment cần thời gian để `available`. Thêm `depends_on` hoặc chạy lại `terraform apply` lần 2.

### EC2 không nhận được `yum update`
Kiểm tra route table của private subnet có route `0.0.0.0/0 → nat-<id>` chưa:
```bash
terraform output
# Lấy subnet ID, rồi kiểm tra trong AWS Console: VPC > Route Tables
```

### `Error: No valid credential sources`
Chưa set credentials. Tạo `secret.tfvars` từ template và điền phương thức xác thực (xem [mục 5](#5-cấu-hình-xác-thực-aws)):
```bash
cp secret.tfvars.example secret.tfvars
```

### State bị lock
```bash
terraform force-unlock <lock-id>
# Lock ID có trong thông báo lỗi
```

---

## Thời gian apply ước tính (lần đầu)

| Resource | Thời gian |
|---|---|
| VPC, Subnets, Route Tables | ~2 phút |
| NAT Gateway (×4) | ~5 phút |
| Transit Gateway | ~3 phút |
| ALB, Security Groups, EC2 | ~3 phút |
| RDS Multi-AZ | ~15–20 phút |
| Directory Service (Managed AD) | ~20–40 phút |
| Client VPN | ~5–10 phút |
| **Tổng** | **~45–75 phút** |