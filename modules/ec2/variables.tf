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
  description = "Public Subnet AZ-1a — nơi đặt Bastion Host"
}
variable "bastion_subnet_1b_id" {
  type        = string
  default     = ""
  description = "Public Subnet AZ-1b — nơi đặt Bastion Host (HA)"
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

# Optional: EC2 key pair name (leave empty to use SSM Session Manager)
variable "key_name" {
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
