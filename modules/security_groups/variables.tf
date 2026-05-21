variable "vpc_id"       { type = string }
variable "env"          { type = string }
variable "vpn_cidr"     { type = string }
variable "rnd_vpc_cidr" { type = string }
variable "prod_vpc_cidr" {
  type        = string
  default     = ""
  description = "CIDR của Production VPC — dùng cho ICMP rule nội bộ"
}
