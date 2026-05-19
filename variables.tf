variable "aws_region" { type = string }

variable "prod_vpc_cidr" { type = string }
variable "prod_vpc_name" { type = string }
variable "prod_public_subnet_1a_cidr"  { type = string }
variable "prod_private_subnet_1a_cidr" { type = string }
variable "prod_db_subnet_1a_cidr"      { type = string }
variable "prod_public_subnet_1b_cidr"  { type = string }
variable "prod_private_subnet_1b_cidr" { type = string }
variable "prod_db_subnet_1b_cidr"      { type = string }

variable "rnd_vpc_cidr" { type = string }
variable "rnd_vpc_name" { type = string }
variable "rnd_public_subnet_2a_cidr"  { type = string }
variable "rnd_private_subnet_2a_cidr" { type = string }
variable "rnd_public_subnet_2b_cidr"  { type = string }
variable "rnd_private_subnet_2b_cidr" { type = string }

variable "ec2_instance_type" { type = string }
variable "ec2_ami"           { type = string }

variable "asg_web_min"     { type = number }
variable "asg_web_max"     { type = number }
variable "asg_web_desired" { type = number }
variable "asg_erp_min"     { type = number }
variable "asg_erp_max"     { type = number }
variable "asg_erp_desired" { type = number }

variable "rds_engine"         { type = string }
variable "rds_engine_version" { type = string }
variable "rds_instance_class" { type = string }
variable "rds_db_name"        { type = string }
variable "rds_username"       { type = string }
variable "rds_password"       { type = string; sensitive = true }

variable "vpn_client_cidr" { type = string }
variable "s3_bucket_name"  { type = string }
