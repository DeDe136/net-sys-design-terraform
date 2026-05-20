# ──────────────────────────────────────────────────────────────────
# variables.tf  —  All input variable declarations
# ──────────────────────────────────────────────────────────────────

# ── AWS Provider ──────────────────────────────────────────────────
variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "aws_profile" {
  type        = string
  description = "AWS credentials profile name (~/.aws/credentials). Để trống để dùng env vars hoặc instance role."
  default     = ""
}

# Phương thức 2: Access Key trực tiếp — uncomment trong providers.tf nếu dùng
variable "aws_access_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Access Key ID — điền vào secret.tfvars, không commit."
}
variable "aws_secret_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Secret Access Key — điền vào secret.tfvars, không commit."
}

variable "aws_role_arn" {
  type        = string
  default     = ""
  description = "IAM Role ARN để assume (phương thức 3) — điền vào secret.tfvars nếu dùng."
}
variable "aws_role_external_id" {
  type    = string
  default = ""
}

# ── Production VPC ────────────────────────────────────────────────
variable "prod_vpc_cidr" { type = string }
variable "prod_vpc_name" { type = string }
variable "prod_public_subnet_1a_cidr"  { type = string }
variable "prod_public_subnet_1b_cidr"  { type = string }
variable "prod_private_subnet_1a_cidr" { type = string }
variable "prod_private_subnet_1b_cidr" { type = string }
variable "prod_db_subnet_1a_cidr"      { type = string }
variable "prod_db_subnet_1b_cidr"      { type = string }

# ── R&D VPC ───────────────────────────────────────────────────────
variable "rnd_vpc_cidr" { type = string }
variable "rnd_vpc_name" { type = string }
variable "rnd_public_subnet_2a_cidr"  { type = string }
variable "rnd_public_subnet_2b_cidr"  { type = string }
variable "rnd_private_subnet_2a_cidr" { type = string }
variable "rnd_private_subnet_2b_cidr" { type = string }

# ── EC2 ───────────────────────────────────────────────────────────
variable "ec2_instance_type" { type = string }
variable "ec2_ami"           { type = string }

variable "ec2_instance_profile_name" {
  type        = string
  description = "Tên IAM instance profile gắn vào TẤT CẢ EC2 (prod Web Portal, ERP/CRM, và R&D). Tạo trong global/iam.tf. Cấp quyền SSM Session Manager + S3 access."
  default     = "ec2-instance-profile"
}

variable "asg_web_min"     { type = number }
variable "asg_web_max"     { type = number }
variable "asg_web_desired" { type = number }
variable "asg_erp_min"     { type = number }
variable "asg_erp_max"     { type = number }
variable "asg_erp_desired" { type = number }

variable "rnd_instance_count_per_az" {
  type        = number
  description = "Số EC2 instance mỗi AZ trong R&D VPC"
  default     = 4
}

# ── RDS ───────────────────────────────────────────────────────────
variable "rds_engine"         { type = string }
variable "rds_engine_version" { type = string }
variable "rds_instance_class" { type = string }
variable "rds_db_name"        { type = string }
variable "rds_username"       { type = string }
variable "rds_password" {
  type        = string
  sensitive   = true
  description = "RDS master password. Set via: export TF_VAR_rds_password='...'"
}

# ── Directory Service (Managed AD) ───────────────────────────────
variable "ds_directory_name" {
  type        = string
  description = "FQDN cho Managed AD, ví dụ: corp.example.com"
}
variable "ds_directory_short_name" {
  type        = string
  description = "NetBIOS short name, ví dụ: CORP"
}
variable "ds_directory_password" {
  type        = string
  sensitive   = true
  description = "Admin password cho Managed AD. Set via: export TF_VAR_ds_directory_password='...'"
}
variable "ds_edition" {
  type        = string
  description = "MicrosoftAD edition: Standard hoặc Enterprise"
  default     = "Standard"
}

# ── Client VPN ────────────────────────────────────────────────────
variable "vpn_client_cidr" {
  type        = string
  description = "CIDR block cấp cho VPN clients, ví dụ: 172.16.0.0/22"
}
variable "vpn_server_certificate_arn" {
  type        = string
  description = "ACM ARN của VPN server certificate. Tạo bằng scripts/generate_vpn_certs.sh"
  default     = ""
}
variable "vpn_client_certificate_arn" {
  type        = string
  description = "ACM ARN của client root certificate. Tạo bằng scripts/generate_vpn_certs.sh"
  default     = ""
}

# ── S3 ────────────────────────────────────────────────────────────
variable "s3_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name cho shared storage"
}
