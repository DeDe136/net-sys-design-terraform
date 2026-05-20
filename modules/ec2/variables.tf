variable "env"           { type = string }
variable "ami"           { type = string }
variable "instance_type" { type = string }

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
  default = 4
}
variable "asg_web_desired" {
  type    = number
  default = 2
}
variable "asg_erp_min" {
  type    = number
  default = 1
}
variable "asg_erp_max" {
  type    = number
  default = 4
}
variable "asg_erp_desired" {
  type    = number
  default = 2
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
  default = 4
}
