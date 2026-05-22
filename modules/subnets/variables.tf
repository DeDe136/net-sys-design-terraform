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

# ── Dedicated TGW subnets (/28) ───────────────────────────────────
# AWS best practice: TGW attachment nên dùng subnet riêng (~250 IPs
# dành cho ENI của TGW), không dùng chung với EC2 private subnet.
# /28 = 16 IPs, đủ cho TGW ENI và HA requirement.
# Đặt null để skip (nếu chưa cần — nhưng nên luôn khai báo cho Prod/R&D).
variable "tgw_subnet_1a_cidr" {
  type        = string
  default     = null
  description = "CIDR /28 cho dedicated TGW attachment subnet AZ-1a. Ví dụ: 10.0.4.0/28"
}
variable "tgw_subnet_1b_cidr" {
  type        = string
  default     = null
  description = "CIDR /28 cho dedicated TGW attachment subnet AZ-1b. Ví dụ: 10.0.4.16/28"
}

variable "az_1a"                  { type = string }
variable "az_1b"                  { type = string }
variable "name_prefix"            { type = string }
variable "igw_id"                 { type = string }
variable "tgw_id"                 { type = string }
variable "remote_vpc_cidr"        { type = string }

# ── TGW Route flag ────────────────────────────────────────────────
# Đặt false ở lần apply đầu (Phase 3) vì TGW attachment chưa tồn tại.
# Đặt true ở lần apply thứ 2 (sau Phase 4) để tạo aws_route sang remote VPC.
# Cách này tránh circular dependency: subnets ↔ tgw_attachments.
variable "enable_tgw_routes" {
  type        = bool
  default     = false
  description = "Bật sau khi TGW attachments đã tạo xong (lần apply thứ 2)."
}

variable "tgw_attachment_ids" {
  type        = list(string)
  default     = []
  description = "DEPRECATED — không còn dùng để guard route. Giữ lại để tránh breaking change nếu state cũ còn tham chiếu."
}
