# ──────────────────────────────────────────────────────────────────
# environments/rnd/terraform.tfvars
# Override values khi deploy môi trường R&D riêng lẻ.
# ──────────────────────────────────────────────────────────────────

aws_region = "us-east-1"

rnd_vpc_cidr = "10.1.0.0/16"
rnd_vpc_name = "R&D VPC"

rnd_public_subnet_2a_cidr  = "10.1.1.0/24"
rnd_public_subnet_2b_cidr  = "10.1.11.0/24"
rnd_private_subnet_2a_cidr = "10.1.2.0/24"
rnd_private_subnet_2b_cidr = "10.1.12.0/24"

ec2_instance_type          = "t3.micro"
ec2_ami                    = "ami-0c02fb55956c7d316"
rnd_instance_count_per_az  = 4

vpn_client_cidr = "172.16.0.0/22"

s3_bucket_name = "s3-prod-shared-<account_id>"

# IAM instance profile — gắn vào tất cả EC2 R&D
ec2_instance_profile_name = "ec2-instance-profile"
