aws_region = "us-east-1"

# ── AWS Authentication ────────────────────────────────────────────
# Tất cả biến nhạy cảm (aws_profile, aws_access_key, aws_secret_key,
# aws_role_arn, rds_password, ds_directory_password, vpn certs)
# được khai báo trong secret.tfvars — KHÔNG đặt ở đây.
#
# Chạy Terraform:
#   terraform plan  -var-file="secret.tfvars"
#   terraform apply -var-file="secret.tfvars"

# ── Production VPC ────────────────────────────────────────────────
prod_vpc_cidr = "10.0.0.0/16"
prod_vpc_name = "Production VPC"

prod_public_subnet_1a_cidr  = "10.0.1.0/24"
prod_public_subnet_1b_cidr  = "10.0.11.0/24"
prod_private_subnet_1a_cidr = "10.0.2.0/24"
prod_private_subnet_1b_cidr = "10.0.12.0/24"
prod_db_subnet_1a_cidr      = "10.0.3.0/24"
prod_db_subnet_1b_cidr      = "10.0.13.0/24"

# ── R&D VPC ───────────────────────────────────────────────────────
rnd_vpc_cidr = "10.1.0.0/16"
rnd_vpc_name = "R&D VPC"

rnd_public_subnet_2a_cidr  = "10.1.1.0/24"
rnd_public_subnet_2b_cidr  = "10.1.11.0/24"
rnd_private_subnet_2a_cidr = "10.1.2.0/24"
rnd_private_subnet_2b_cidr = "10.1.12.0/24"

# ── EC2 ───────────────────────────────────────────────────────────
ec2_instance_type = "t3.micro"
ec2_ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 — us-east-1

ec2_instance_profile_name = "ec2-instance-profile"

asg_web_min     = 1
asg_web_max     = 4
asg_web_desired = 2

asg_erp_min     = 1
asg_erp_max     = 4
asg_erp_desired = 2

rnd_instance_count_per_az = 4

# ── RDS ───────────────────────────────────────────────────────────
rds_engine         = "mysql"
rds_engine_version = "8.0"
rds_instance_class = "db.t3.medium"
rds_db_name        = "proddb"
rds_username       = "admin"

# ── Directory Service ─────────────────────────────────────────────
ds_directory_name       = "corp.example.com"
ds_directory_short_name = "CORP"
ds_edition              = "Standard"

# ── Client VPN ────────────────────────────────────────────────────
vpn_client_cidr = "172.16.0.0/22"

# ── S3 ────────────────────────────────────────────────────────────
# Phải globally unique — thay <account_id> bằng AWS account ID thực tế
s3_bucket_name = "s3-prod-shared-<account_id>"

# ── TGW Dedicated Subnets (/28) ───────────────────────────────────
# FIX 2: Tách riêng khỏi EC2 private subnets theo AWS best practice.
# Prod VPC (10.0.0.0/16): dùng 10.0.4.0/27 chia đôi thành 2 /28
prod_tgw_subnet_1a_cidr = "10.0.4.0/28"   # 10.0.4.0  – 10.0.4.15  → AZ-1a
prod_tgw_subnet_1b_cidr = "10.0.4.16/28"  # 10.0.4.16 – 10.0.4.31  → AZ-1b

# R&D VPC (10.1.0.0/16): dùng 10.1.3.0/27 chia đôi thành 2 /28
rnd_tgw_subnet_2a_cidr = "10.1.3.0/28"    # 10.1.3.0  – 10.1.3.15  → AZ-2a
rnd_tgw_subnet_2b_cidr = "10.1.3.16/28"   # 10.1.3.16 – 10.1.3.31  → AZ-2b

# ── TGW Route Flag ────────────────────────────────────────────────
# FIX 1: Workflow 2 lần apply để tránh circular dependency.
# Lần 1 apply: giữ false → tạo hạ tầng + TGW attachments
# Lần 2 apply: đổi thành true → tạo aws_route TGW trong private route tables
enable_tgw_routes = false
