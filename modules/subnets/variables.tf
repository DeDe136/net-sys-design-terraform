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

# FIX: IDs của TGW Attachments dùng để guard aws_route TGW.
# Route TGW chỉ được tạo khi list này không rỗng (tức attachment đã tồn tại),
# tránh lỗi AWS API "route với transit_gateway_id không hợp lệ vì VPC chưa
# được attach" xảy ra khi route nằm inline trong aws_route_table.
variable "tgw_attachment_ids" {
  type        = list(string)
  default     = []
  description = "TGW Attachment IDs — truyền vào sau Phase 4 để kích hoạt aws_route TGW."
}
