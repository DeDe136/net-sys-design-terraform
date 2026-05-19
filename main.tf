terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket         = "your-tfstate-bucket"
  #   key            = "aws-infra/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────
# Production VPC + Subnets
# ─────────────────────────────────────────────────────────────────
module "prod_vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.prod_vpc_cidr
  vpc_name = var.prod_vpc_name
}

module "prod_subnets" {
  source = "./modules/subnets"
  vpc_id = module.prod_vpc.vpc_id

  public_subnet_1a_cidr  = var.prod_public_subnet_1a_cidr
  public_subnet_1b_cidr  = var.prod_public_subnet_1b_cidr
  private_subnet_1a_cidr = var.prod_private_subnet_1a_cidr
  private_subnet_1b_cidr = var.prod_private_subnet_1b_cidr
  db_subnet_1a_cidr      = var.prod_db_subnet_1a_cidr
  db_subnet_1b_cidr      = var.prod_db_subnet_1b_cidr

  az_1a       = "${var.aws_region}a"
  az_1b       = "${var.aws_region}b"
  name_prefix = "prod"
  igw_id      = module.prod_vpc.igw_id
  tgw_id      = module.transit_gateway.tgw_id
  remote_vpc_cidr = var.rnd_vpc_cidr
}

# ─────────────────────────────────────────────────────────────────
# R&D VPC + Subnets
# ─────────────────────────────────────────────────────────────────
module "rnd_vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.rnd_vpc_cidr
  vpc_name = var.rnd_vpc_name
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

  az_1a       = "${var.aws_region}a"
  az_1b       = "${var.aws_region}b"
  name_prefix = "rnd"
  igw_id      = module.rnd_vpc.igw_id
  tgw_id      = module.transit_gateway.tgw_id
  remote_vpc_cidr = var.prod_vpc_cidr
}

# ─────────────────────────────────────────────────────────────────
# Transit Gateway (kết nối Prod ↔ R&D ↔ VPN)
# ─────────────────────────────────────────────────────────────────
module "transit_gateway" {
  source = "./modules/transit_gateway"

  prod_vpc_id            = module.prod_vpc.vpc_id
  prod_private_subnet_ids = [
    module.prod_subnets.private_subnet_1a_id,
    module.prod_subnets.private_subnet_1b_id,
  ]
  rnd_vpc_id            = module.rnd_vpc.vpc_id
  rnd_private_subnet_ids = [
    module.rnd_subnets.private_subnet_1a_id,
    module.rnd_subnets.private_subnet_1b_id,
  ]
}

# ─────────────────────────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────────────────────────
module "prod_security_groups" {
  source  = "./modules/security_groups"
  vpc_id  = module.prod_vpc.vpc_id
  env     = "prod"
  vpn_cidr = var.vpn_client_cidr
  rnd_vpc_cidr = var.rnd_vpc_cidr
}

module "rnd_security_groups" {
  source  = "./modules/security_groups"
  vpc_id  = module.rnd_vpc.vpc_id
  env     = "rnd"
  vpn_cidr = var.vpn_client_cidr
  rnd_vpc_cidr = var.rnd_vpc_cidr
}

# ─────────────────────────────────────────────────────────────────
# Application Load Balancer (Production)
# ─────────────────────────────────────────────────────────────────
module "prod_alb" {
  source          = "./modules/alb"
  vpc_id          = module.prod_vpc.vpc_id
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

  alb_web_tg_arn = module.prod_alb.web_tg_arn
  alb_erp_tg_arn = module.prod_alb.erp_tg_arn

  asg_web_min     = var.asg_web_min
  asg_web_max     = var.asg_web_max
  asg_web_desired = var.asg_web_desired
  asg_erp_min     = var.asg_erp_min
  asg_erp_max     = var.asg_erp_max
  asg_erp_desired = var.asg_erp_desired
}

# ─────────────────────────────────────────────────────────────────
# EC2 — R&D Testing (fixed instances, không ASG)
# ─────────────────────────────────────────────────────────────────
module "rnd_ec2" {
  source        = "./modules/ec2"
  env           = "rnd"
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  rnd_subnet_2a_id  = module.rnd_subnets.private_subnet_1a_id
  rnd_subnet_2b_id  = module.rnd_subnets.private_subnet_1b_id
  sg_rnd_id         = module.rnd_security_groups.sg_rnd_ec2_id
  rnd_instance_count_per_az = 4
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
# S3 Bucket + VPC Gateway Endpoints
# ─────────────────────────────────────────────────────────────────
module "s3" {
  source      = "./modules/s3"
  bucket_name = var.s3_bucket_name
}

module "prod_s3_endpoint" {
  source         = "./modules/endpoints"
  vpc_id         = module.prod_vpc.vpc_id
  route_table_ids = [
    module.prod_subnets.private_rt_1a_id,
    module.prod_subnets.private_rt_1b_id,
  ]
  aws_region = var.aws_region
  name       = "vpce-prod-s3"
}

module "rnd_s3_endpoint" {
  source         = "./modules/endpoints"
  vpc_id         = module.rnd_vpc.vpc_id
  route_table_ids = [
    module.rnd_subnets.private_rt_1a_id,
    module.rnd_subnets.private_rt_1b_id,
  ]
  aws_region = var.aws_region
  name       = "vpce-rnd-s3"
}

# ─────────────────────────────────────────────────────────────────
# Client VPN (Remote Staff → Transit Gateway)
# ─────────────────────────────────────────────────────────────────
module "client_vpn" {
  source           = "./modules/vpn"
  client_cidr      = var.vpn_client_cidr
  target_subnet_id = module.prod_subnets.private_subnet_1a_id
  vpc_id           = module.prod_vpc.vpc_id
  name             = "client-vpn-prod"
}
