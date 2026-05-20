# ──────────────────────────────────────────────────────────────────
# environments/production/terraform.tfvars
# Override values khi deploy môi trường Production riêng lẻ.
# Dùng khi bạn tách environments thành workspace riêng.
#
# Cách dùng:
#   cd <root>
#   terraform workspace new production
#   terraform apply -var-file=environments/production/terraform.tfvars
# ──────────────────────────────────────────────────────────────────

aws_region = "us-east-1"

prod_vpc_cidr = "10.0.0.0/16"
prod_vpc_name = "Production VPC"

prod_public_subnet_1a_cidr  = "10.0.1.0/24"
prod_public_subnet_1b_cidr  = "10.0.11.0/24"
prod_private_subnet_1a_cidr = "10.0.2.0/24"
prod_private_subnet_1b_cidr = "10.0.12.0/24"
prod_db_subnet_1a_cidr      = "10.0.3.0/24"
prod_db_subnet_1b_cidr      = "10.0.13.0/24"

ec2_instance_type = "t3.small"   # Upsize cho Production thực tế
ec2_ami           = "ami-0c02fb55956c7d316"

asg_web_min     = 2
asg_web_max     = 6
asg_web_desired = 2

asg_erp_min     = 2
asg_erp_max     = 6
asg_erp_desired = 2

rds_engine         = "mysql"
rds_engine_version = "8.0"
rds_instance_class = "db.t3.medium"
rds_db_name        = "proddb"
rds_username       = "admin"

ds_directory_name       = "corp.example.com"
ds_directory_short_name = "CORP"
ds_edition              = "Standard"

vpn_client_cidr = "172.16.0.0/22"

s3_bucket_name = "s3-prod-shared-<account_id>"

# IAM instance profile — gắn vào tất cả EC2 prod (Web Portal + ERP/CRM)
ec2_instance_profile_name = "ec2-instance-profile"
