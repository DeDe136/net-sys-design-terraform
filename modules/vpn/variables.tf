variable "client_cidr"             { type = string }
variable "target_subnet_id"        { type = string }
variable "target_subnet_1b_id" {
  type        = string
  description = "Private subnet AZ-1b — dùng cho VPN association thứ 2 (HA)"
}
variable "vpc_id"                  { type = string }
variable "name"                    { type = string }
variable "server_certificate_arn"  { type = string }
variable "client_certificate_arn"  { type = string }
variable "directory_id" {
  type        = string
  description = "ID của AWS Managed Microsoft AD dùng để xác thực VPN users (Active Directory authentication)"
}
