aws_region = "us-east-1"

# ─── Production VPC ───────────────────────────────────────────────
prod_vpc_cidr = "10.0.0.0/16"
prod_vpc_name = "Production VPC"

prod_public_subnet_1a_cidr  = "10.0.1.0/24"
prod_private_subnet_1a_cidr = "10.0.2.0/24"
prod_db_subnet_1a_cidr      = "10.0.3.0/24"
prod_public_subnet_1b_cidr  = "10.0.11.0/24"
prod_private_subnet_1b_cidr = "10.0.12.0/24"
prod_db_subnet_1b_cidr      = "10.0.13.0/24"

# ─── R&D VPC ──────────────────────────────────────────────────────
rnd_vpc_cidr = "10.1.0.0/16"
rnd_vpc_name = "R&D VPC"

rnd_public_subnet_2a_cidr  = "10.1.1.0/24"
rnd_private_subnet_2a_cidr = "10.1.2.0/24"
rnd_public_subnet_2b_cidr  = "10.1.11.0/24"
rnd_private_subnet_2b_cidr = "10.1.12.0/24"

# ─── EC2 ──────────────────────────────────────────────────────────
ec2_instance_type = "t3.micro"
ec2_ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 us-east-1

# Auto Scaling — Web Portal
asg_web_min     = 1
asg_web_max     = 4
asg_web_desired = 2

# Auto Scaling — ERP/CRM
asg_erp_min     = 1
asg_erp_max     = 4
asg_erp_desired = 2

# ─── RDS ──────────────────────────────────────────────────────────
rds_engine         = "mysql"
rds_engine_version = "8.0"
rds_instance_class = "db.t3.medium"
rds_db_name        = "proddb"
rds_username       = "admin"
# rds_password set via env var TF_VAR_rds_password

# ─── Client VPN ───────────────────────────────────────────────────
vpn_client_cidr = "172.16.0.0/22"

# ─── S3 ───────────────────────────────────────────────────────────
s3_bucket_name = "s3-prod-shared"
