variable "env"           { type = string }
variable "ami"           { type = string }
variable "instance_type" { type = string }

# Bastion Host variables (Production only)
variable "bastion_instance_type" {
  type        = string
  default     = "t2.micro"
  description = "Instance type for Bastion Host — jump host only, no compute needed. t2.micro = Free Tier eligible."
}
variable "bastion_subnet_1a_id" {
  type        = string
  default     = ""
  description = "Private Subnet AZ-1a — nơi đặt Bastion Host. Dùng private subnet để SSM Agent đi qua NAT GW (không cần Public IP)."
}
variable "bastion_subnet_1b_id" {
  type        = string
  default     = ""
  description = "Private Subnet AZ-1b — nơi đặt Bastion Host (HA). Dùng private subnet để SSM Agent đi qua NAT GW."
}
variable "sg_bastion_id" {
  type        = string
  default     = ""
  description = "Security Group ID của Bastion Host"
}

# Optional: IAM instance profile for SSM access
variable "iam_instance_profile" {
  type    = string
  default = ""
}

# Production variables (not used in rnd)
variable "web_subnet_ids" {
  type    = list(string)
  default = []
}
variable "erp_subnet_ids" {
  type    = list(string)
  default = []
}
variable "sg_web_id" {
  type    = string
  default = ""
}
variable "sg_erp_id" {
  type    = string
  default = ""
}

# ALB chỉ gắn với Web Portal — không cần alb_erp_tg_arn nữa
variable "alb_web_tg_arn" {
  type    = string
  default = ""
}

variable "asg_web_min" {
  type    = number
  default = 1
}
variable "asg_web_max" {
  type    = number
  default = 2
}
variable "asg_web_desired" {
  type    = number
  default = 1
}
variable "asg_erp_min" {
  type    = number
  default = 1
}
variable "asg_erp_max" {
  type    = number
  default = 2
}
variable "asg_erp_desired" {
  type    = number
  default = 1
}

# R&D variables (not used in prod)
variable "rnd_subnet_2a_id" {
  type    = string
  default = ""
}
variable "rnd_subnet_2b_id" {
  type    = string
  default = ""
}
variable "sg_rnd_id" {
  type    = string
  default = ""
}
variable "rnd_instance_count_per_az" {
  type    = number
  default = 1
  description = "Number of R&D EC2 instances per AZ. Keep at 1 for dev/lab to stay within vCPU limits."
}

# ─────────────────────────────────────────────────────────────────
# SSH Key Pair — Public key paths (tạo bên ngoài Terraform bằng ssh-keygen)
#
# Workflow:
#   1. Chạy scripts/generate_ssh_keys.sh để sinh key pairs
#   2. Private keys lưu tại ssh-keys/<env>/ (gitignored)
#   3. Terraform đọc public key (.pub) từ đường dẫn dưới đây
#
# Luồng SSH:
#   Staff → (SSM hoặc Client VPN) → Bastion
#   Bastion --(bastion key)-→ EC2 Web/ERP (Staff dùng key web/erp, agent forwarding)
#   R&D staff → Client VPN → EC2 R&D trực tiếp (không qua Bastion)
# ─────────────────────────────────────────────────────────────────

variable "bastion_public_key_path" {
  type        = string
  default     = ""
  description = "Đường dẫn tới public key (.pub) của Bastion Host. Dùng để tạo aws_key_pair. Private key lưu tại ssh-keys/prod/bastion.pem (gitignored)."
}

variable "web_public_key_path" {
  type        = string
  default     = ""
  description = "Đường dẫn tới public key (.pub) của EC2 Web Portal. Staff SSH vào Web qua Bastion dùng key này (agent forwarding). Private key lưu tại ssh-keys/prod/web.pem."
}

variable "erp_public_key_path" {
  type        = string
  default     = ""
  description = "Đường dẫn tới public key (.pub) của EC2 ERP/CRM. Staff SSH vào ERP qua Bastion dùng key này (agent forwarding). Private key lưu tại ssh-keys/prod/erp.pem."
}

variable "rnd_public_key_path" {
  type        = string
  default     = ""
  description = "Đường dẫn tới public key (.pub) của EC2 R&D. R&D staff SSH trực tiếp vào EC2 R&D (không qua Bastion). Private key lưu tại ssh-keys/rnd/rnd.pem."
}
