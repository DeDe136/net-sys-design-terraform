# ──────────────────────────────────────────────────────────────────
# main.tf  —  Root module
#
# Thứ tự dependency:
#   Phase 1: VPCs
#   Phase 2: Transit Gateway (chỉ tạo TGW, KHÔNG tạo attachments)
#   Phase 3: Subnets — tgw_attachment_ids=[] nên aws_route TGW chưa tạo
#   Phase 4: TGW Attachments (dùng private subnet IDs từ Phase 3)
#   Phase 4.5: prod_subnets + rnd_subnets refresh với tgw_attachment_ids
#              đã có → aws_route TGW được tạo (count 0→1)
#   Phase 5: Security Groups, ALB, EC2, RDS, DS, EFS, S3, VPN
#
# FIX 1 (TGW race condition):
#   Route TGW KHÔNG đặt inline trong aws_route_table — AWS validate
#   attachment ngay lúc tạo route. Thay bằng aws_route riêng biệt
#   với count = length(tgw_attachment_ids) > 0.
#
# FIX 2 (TGW duplicate):
#   Transit Gateway chỉ tạo 1 lần (create_tgw=true ở Phase 2).
#   Phase 4 dùng create_tgw=false + existing_tgw_id để chỉ tạo
#   attachments mà KHÔNG tạo TGW mới.
# ──────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────
# Phase 1: VPCs
# ─────────────────────────────────────────────────────────────────
module "prod_vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.prod_vpc_cidr
  vpc_name = var.prod_vpc_name
}

module "rnd_vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.rnd_vpc_cidr
  vpc_name = var.rnd_vpc_name
}

# ─────────────────────────────────────────────────────────────────
# Phase 2: Transit Gateway (tạo TGW, chưa attach)
# ─────────────────────────────────────────────────────────────────
module "transit_gateway" {
  source      = "./modules/transit_gateway"
  create_tgw  = true   # Chỉ tạo TGW resource, KHÔNG tạo attachments
  prod_vpc_id = module.prod_vpc.vpc_id
  rnd_vpc_id  = module.rnd_vpc.vpc_id
  # Để trống — attachments tạo ở Phase 4 sau khi subnets sẵn sàng
  prod_private_subnet_ids = []
  rnd_private_subnet_ids  = []
}

# ─────────────────────────────────────────────────────────────────
# Phase 3: Subnets
# tgw_attachment_ids=[] → aws_route TGW chưa tạo (count=0).
# Sau Phase 4, Terraform truyền attachment IDs vào → count=1 → route được tạo.
# ─────────────────────────────────────────────────────────────────
module "prod_subnets" {
  source = "./modules/subnets"
  vpc_id = module.prod_vpc.vpc_id

  public_subnet_1a_cidr  = var.prod_public_subnet_1a_cidr
  public_subnet_1b_cidr  = var.prod_public_subnet_1b_cidr
  private_subnet_1a_cidr = var.prod_private_subnet_1a_cidr
  private_subnet_1b_cidr = var.prod_private_subnet_1b_cidr
  db_subnet_1a_cidr      = var.prod_db_subnet_1a_cidr
  db_subnet_1b_cidr      = var.prod_db_subnet_1b_cidr

  az_1a           = "${var.aws_region}a"
  az_1b           = "${var.aws_region}b"
  name_prefix     = "prod"
  igw_id          = module.prod_vpc.igw_id
  tgw_id          = module.transit_gateway.tgw_id
  remote_vpc_cidr = var.rnd_vpc_cidr

  # compact() lọc null — rỗng khi Phase 4 chưa chạy, có giá trị sau đó
  tgw_attachment_ids = compact([
    module.tgw_attachments.tgw_attach_prod_id,
    module.tgw_attachments.tgw_attach_rnd_id,
  ])

  depends_on = [module.transit_gateway]
}

module "rnd_subnets" {
  source = "./modules/subnets"
  vpc_id = module.rnd_vpc.vpc_id

  public_subnet_1a_cidr  = var.rnd_public_subnet_2a_cidr
  public_subnet_1b_cidr  = var.rnd_public_subnet_2b_cidr
  private_subnet_1a_cidr = var.rnd_private_subnet_2a_cidr
  private_subnet_1b_cidr = var.rnd_private_subnet_2b_cidr
  db_subnet_1a_cidr      = null
  db_subnet_1b_cidr      = null

  az_1a           = "${var.aws_region}a"
  az_1b           = "${var.aws_region}b"
  name_prefix     = "rnd"
  igw_id          = module.rnd_vpc.igw_id
  tgw_id          = module.transit_gateway.tgw_id
  remote_vpc_cidr = var.prod_vpc_cidr

  tgw_attachment_ids = compact([
    module.tgw_attachments.tgw_attach_prod_id,
    module.tgw_attachments.tgw_attach_rnd_id,
  ])

  depends_on = [module.transit_gateway]
}

# ─────────────────────────────────────────────────────────────────
# Phase 4: TGW Attachments (sau khi subnets đã tạo xong)
# FIX: Dùng create_tgw=false + existing_tgw_id thay vì gọi module
#      riêng biệt (sẽ tạo TGW mới — BUG).
# ─────────────────────────────────────────────────────────────────
module "tgw_attachments" {
  source          = "./modules/transit_gateway"
  create_tgw      = false                           # KHÔNG tạo TGW mới
  existing_tgw_id = module.transit_gateway.tgw_id  # Dùng TGW đã tạo ở Phase 2
  prod_vpc_id     = module.prod_vpc.vpc_id
  rnd_vpc_id      = module.rnd_vpc.vpc_id

  prod_private_subnet_ids = [
    module.prod_subnets.private_subnet_1a_id,
    module.prod_subnets.private_subnet_1b_id,
  ]
  rnd_private_subnet_ids = [
    module.rnd_subnets.private_subnet_1a_id,
    module.rnd_subnets.private_subnet_1b_id,
  ]

  depends_on = [module.prod_subnets, module.rnd_subnets]
}

# ─────────────────────────────────────────────────────────────────
# Phase 5: Security Groups
# ─────────────────────────────────────────────────────────────────
module "prod_security_groups" {
  source       = "./modules/security_groups"
  vpc_id       = module.prod_vpc.vpc_id
  env          = "prod"
  vpn_cidr     = var.vpn_client_cidr
  rnd_vpc_cidr = var.rnd_vpc_cidr
}

module "rnd_security_groups" {
  source       = "./modules/security_groups"
  vpc_id       = module.rnd_vpc.vpc_id
  env          = "rnd"
  vpn_cidr     = var.vpn_client_cidr
  rnd_vpc_cidr = var.rnd_vpc_cidr
}

# ─────────────────────────────────────────────────────────────────
# Application Load Balancer (Production only)
# 1 ALB multi-AZ span cả 2 public subnet (best practice)
# ─────────────────────────────────────────────────────────────────
module "prod_alb" {
  source = "./modules/alb"
  vpc_id = module.prod_vpc.vpc_id
  public_subnet_ids = [
    module.prod_subnets.public_subnet_1a_id,
    module.prod_subnets.public_subnet_1b_id,
  ]
  sg_alb_id = module.prod_security_groups.sg_alb_id
  name      = "alb-prod"
}

# ─────────────────────────────────────────────────────────────────
# EC2 Auto Scaling — Production
# ─────────────────────────────────────────────────────────────────
module "prod_ec2" {
  source        = "./modules/ec2"
  env           = "prod"
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  iam_instance_profile = var.ec2_instance_profile_name

  web_subnet_ids = [
    module.prod_subnets.private_subnet_1a_id,
    module.prod_subnets.private_subnet_1b_id,
  ]
  erp_subnet_ids = [
    module.prod_subnets.private_subnet_1a_id,
    module.prod_subnets.private_subnet_1b_id,
  ]

  sg_web_id = module.prod_security_groups.sg_ec2_web_id
  sg_erp_id = module.prod_security_groups.sg_ec2_erp_id

  # ALB chỉ load balance cho Web Portal
  # ERP/CRM nhận traffic nội bộ từ Web Portal, không gắn ALB
  alb_web_tg_arn = module.prod_alb.web_tg_arn

  asg_web_min     = var.asg_web_min
  asg_web_max     = var.asg_web_max
  asg_web_desired = var.asg_web_desired
  asg_erp_min     = var.asg_erp_min
  asg_erp_max     = var.asg_erp_max
  asg_erp_desired = var.asg_erp_desired
}

# ─────────────────────────────────────────────────────────────────
# EC2 — R&D Testing (rnd_instance_count_per_az per AZ, no ASG)
# ─────────────────────────────────────────────────────────────────
module "rnd_ec2" {
  source        = "./modules/ec2"
  env           = "rnd"
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  iam_instance_profile = var.ec2_instance_profile_name

  rnd_subnet_2a_id          = module.rnd_subnets.private_subnet_1a_id
  rnd_subnet_2b_id          = module.rnd_subnets.private_subnet_1b_id
  sg_rnd_id                 = module.rnd_security_groups.sg_rnd_ec2_id
  rnd_instance_count_per_az = var.rnd_instance_count_per_az
}

# ─────────────────────────────────────────────────────────────────
# RDS MySQL Multi-AZ (Production)
# ─────────────────────────────────────────────────────────────────
module "prod_rds" {
  source = "./modules/rds"

  db_subnet_ids = [
    module.prod_subnets.db_subnet_1a_id,
    module.prod_subnets.db_subnet_1b_id,
  ]
  sg_rds_id      = module.prod_security_groups.sg_rds_id
  engine         = var.rds_engine
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class
  db_name        = var.rds_db_name
  username       = var.rds_username
  password       = var.rds_password
}

# ─────────────────────────────────────────────────────────────────
# Directory Service — AWS Managed Microsoft AD (Production)
# ─────────────────────────────────────────────────────────────────
module "prod_directory_service" {
  source = "./modules/directory_service"

  name    = "ds-prod"
  vpc_id  = module.prod_vpc.vpc_id
  subnet_ids = [
    module.prod_subnets.db_subnet_1a_id,
    module.prod_subnets.db_subnet_1b_id,
  ]

  directory_name       = var.ds_directory_name
  directory_short_name = var.ds_directory_short_name
  directory_password   = var.ds_directory_password
  edition              = var.ds_edition
}

# ─────────────────────────────────────────────────────────────────
# EFS — R&D Project Data
# ─────────────────────────────────────────────────────────────────
module "rnd_efs" {
  source = "./modules/efs"

  subnet_ids = [
    module.rnd_subnets.private_subnet_1a_id,
    module.rnd_subnets.private_subnet_1b_id,
  ]
  sg_efs_id = module.rnd_security_groups.sg_efs_id
  name      = "efs-rnd-project-data"
}

# ─────────────────────────────────────────────────────────────────
# S3 VPC Gateway Endpoints (tạo trước S3 bucket policy)
# ─────────────────────────────────────────────────────────────────
module "prod_s3_endpoint" {
  source = "./modules/endpoints"
  vpc_id = module.prod_vpc.vpc_id
  route_table_ids = [
    module.prod_subnets.private_rt_1a_id,
    module.prod_subnets.private_rt_1b_id,
    module.prod_subnets.public_rt_id,
  ]
  aws_region = var.aws_region
  name       = "vpce-prod-s3"
}

module "rnd_s3_endpoint" {
  source = "./modules/endpoints"
  vpc_id = module.rnd_vpc.vpc_id
  route_table_ids = [
    module.rnd_subnets.private_rt_1a_id,
    module.rnd_subnets.private_rt_1b_id,
    module.rnd_subnets.public_rt_id,
  ]
  aws_region = var.aws_region
  name       = "vpce-rnd-s3"
}

# ─────────────────────────────────────────────────────────────────
# S3 Bucket (restrict access via VPC Endpoints only)
# ─────────────────────────────────────────────────────────────────
module "s3" {
  source      = "./modules/s3"
  bucket_name = var.s3_bucket_name
  vpc_endpoint_ids = [
    module.prod_s3_endpoint.endpoint_id,
    module.rnd_s3_endpoint.endpoint_id,
  ]

  depends_on = [module.prod_s3_endpoint, module.rnd_s3_endpoint]
}

# ─────────────────────────────────────────────────────────────────
# Client VPN (Remote Staff → Transit Gateway → Prod/R&D VPCs)
# FIX: Associate VPN với 2 subnet (AZ-1a + AZ-1b) để HA
#
# ⚠ CHƯA ENABLE: cần ACM certificates trước khi bỏ comment
# Bước 1: chạy scripts/generate_vpn_certs.sh
# Bước 2: điền vpn_server_certificate_arn + vpn_client_certificate_arn vào secret.tfvars
# Bước 3: bỏ comment block bên dưới rồi terraform apply
# ─────────────────────────────────────────────────────────────────
# module "client_vpn" {
#   source              = "./modules/vpn"
#   client_cidr         = var.vpn_client_cidr
#   target_subnet_id    = module.prod_subnets.private_subnet_1a_id
#   target_subnet_1b_id = module.prod_subnets.private_subnet_1b_id
#   vpc_id              = module.prod_vpc.vpc_id
#   name                = "client-vpn-prod"
#
#   server_certificate_arn = var.vpn_server_certificate_arn
#   client_certificate_arn = var.vpn_client_certificate_arn
# }
