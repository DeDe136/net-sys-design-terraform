variable "vpc_id"                 { type = string }
variable "public_subnet_1a_cidr"  { type = string }
variable "public_subnet_1b_cidr"  { type = string }
variable "private_subnet_1a_cidr" { type = string }
variable "private_subnet_1b_cidr" { type = string }
variable "db_subnet_1a_cidr" {
  type    = string
  default = null
}
variable "db_subnet_1b_cidr" {
  type    = string
  default = null
}
variable "az_1a"                  { type = string }
variable "az_1b"                  { type = string }
variable "name_prefix"            { type = string }
variable "igw_id"                 { type = string }
variable "tgw_id"                 { type = string }
variable "remote_vpc_cidr"        { type = string }
